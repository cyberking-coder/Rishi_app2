import type { Profile } from "./types";

export type AppRole = "admin" | "retreat_user" | "free_user";

/**
 * Panel roles allowed into the admin dashboard. Kept separate from the
 * end-user Free/Retreat/Admin model below — a "support" or
 * "content_manager" panel account is a staff permission, not the same
 * concept as a paying end user's access tier.
 */
export const ADMIN_PANEL_ROLES = ["admin", "content_manager", "support"] as const;

export function isAdminPanelRole(role: string): boolean {
  return (ADMIN_PANEL_ROLES as readonly string[]).includes(role);
}

/**
 * Mirrors the same end-user role derivation used in the mobile app and the
 * Supabase edge functions (supabase/functions/_shared/roles.ts). Not yet
 * wired into any admin page — available for a future Users-table role
 * badge or similar.
 */
export function resolveAppRole(
  profile: Pick<Profile, "role" | "access_expires_at">,
): AppRole {
  if (isAdminPanelRole(profile.role)) return "admin";
  const hasAccess =
    !profile.access_expires_at || new Date(profile.access_expires_at) > new Date();
  return hasAccess ? "retreat_user" : "free_user";
}
