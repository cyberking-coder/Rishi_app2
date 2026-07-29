import type { Profile } from "./types";

const STAFF_ROLES = ["admin", "content_manager", "support"];

export type UserTier = "admin" | "retreat" | "free";

/** admin: staff role, unlimited access to everything.
 *  retreat: an active (possibly unlimited) access window was granted.
 *  free: never granted a window (self-signup default) or it expired.
 *
 *  Mirrors `resolve_user_tier` in supabase/migrations — keep in sync. */
export function resolveTier(profile: Profile): UserTier {
  if (STAFF_ROLES.includes(profile.role)) return "admin";

  if (profile.access_started_at) {
    const expiresAt = profile.access_expires_at;
    if (!expiresAt || new Date(expiresAt) > new Date()) return "retreat";
  }

  return "free";
}
