import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { isAdminPanelRole } from "@/lib/roles";
import type { Profile } from "@/lib/types";

/**
 * Resolves the current admin's profile, or redirects to /login. Used by
 * the dashboard layout and every privileged server action so authorization
 * is enforced server-side, independent of any client checks.
 */
export async function requireAdmin(): Promise<Profile> {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) redirect("/login");

  const { data: profile } = await supabase
    .from("profiles")
    .select("*")
    .eq("id", user.id)
    .single<Profile>();

  if (!profile || !isAdminPanelRole(profile.role)) {
    redirect("/login?error=not_authorized");
  }

  return profile;
}

export async function getCurrentProfile(): Promise<Profile | null> {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const { data } = await supabase
    .from("profiles")
    .select("*")
    .eq("id", user.id)
    .single<Profile>();

  return data ?? null;
}
