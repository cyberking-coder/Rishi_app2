// Shared end-user role resolution: Admin / Retreat User / Free User.
//
// This governs whether a user may stream content at all (consumed by
// issue-audio-license and issue-playback-license). It is deliberately
// separate from issue-upload-url's own admin-role list, which controls a
// finer-grained staff permission (who may upload content) that doesn't map
// 1:1 onto this 3-tier end-user model — see that function for details.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type SupabaseClient = ReturnType<typeof createClient>;

export type AppRole = "admin" | "retreat_user" | "free_user";

const ADMIN_PANEL_ROLES = new Set(["admin", "content_manager", "support"]);

export class RoleError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

/**
 * Resolves a user's AppRole. Staff/admin-panel roles always resolve to
 * "admin". Everyone else is "retreat_user" while their access window is
 * open, else "free_user" — reusing the existing has_active_access RPC as
 * the single source of truth for "has access" rather than re-deriving the
 * date comparison here.
 */
export async function resolveAppRole(
  supabase: SupabaseClient,
  userId: string,
): Promise<AppRole> {
  const { data: profile, error } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", userId)
    .maybeSingle<{ role: string }>();

  if (error || !profile) {
    throw new RoleError(403, "Profile not found");
  }

  if (ADMIN_PANEL_ROLES.has(profile.role)) return "admin";

  const { data: hasAccess } = await supabase.rpc("has_active_access", {
    p_user_id: userId,
  });

  return hasAccess ? "retreat_user" : "free_user";
}

/**
 * Resolves the caller's AppRole and throws a RoleError if it isn't in
 * `allowed`. `deniedMessage`/`deniedStatus` let each call site preserve its
 * own existing error contract instead of a generic one.
 */
export async function requireRole(
  supabase: SupabaseClient,
  userId: string,
  allowed: AppRole[],
  deniedMessage = "Forbidden",
  deniedStatus = 403,
): Promise<AppRole> {
  const role = await resolveAppRole(supabase, userId);
  if (!allowed.includes(role)) {
    throw new RoleError(deniedStatus, deniedMessage);
  }
  return role;
}
