import { createClient } from "@supabase/supabase-js";
import { env } from "@/lib/env";

/**
 * Service-role Supabase client. BYPASSES RLS — server-only, never import
 * this into a client component. Used for privileged admin mutations
 * (creating auth users, resetting another user's device, etc.) AFTER the
 * caller has been verified as an admin via `requireAdmin()`.
 */
export function createAdminClient() {
  return createClient(env.supabaseUrl(), env.supabaseServiceRoleKey(), {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}
