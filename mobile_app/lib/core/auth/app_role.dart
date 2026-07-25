/// The three end-user access tiers used across the app and backend: an
/// authenticated user always resolves to exactly one of these.
enum AppRole { admin, retreatUser, freeUser }

/// Mirrors the same derivation used server-side (Supabase edge functions,
/// see supabase/functions/_shared/roles.ts) and in the admin dashboard
/// (admin/src/lib/roles.ts): staff/admin-panel roles are always Admin;
/// everyone else is Retreat while their access window is open, else Free.
AppRole resolveAppRole({required String role, required bool hasAccess}) {
  const adminRoles = {'admin', 'content_manager', 'support'};
  if (adminRoles.contains(role)) return AppRole.admin;
  return hasAccess ? AppRole.retreatUser : AppRole.freeUser;
}
