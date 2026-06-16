"use server";

import { revalidatePath } from "next/cache";
import { requireAdmin } from "@/lib/auth";
import { createAdminClient } from "@/lib/supabase/admin";
import type { UserRole, UserStatus } from "@/lib/types";

export interface CreateUserInput {
  email: string;
  password: string;
  displayName?: string;
  role: UserRole;
  subscriptionTier: string;
}

export type ActionResult = { ok: true } | { ok: false; error: string };

/** Creates an auth user (service role) and sets their profile role/tier.
 *  The profile row itself is auto-created by the `handle_new_user` trigger. */
export async function createUser(input: CreateUserInput): Promise<ActionResult> {
  await requireAdmin();
  const admin = createAdminClient();

  const { data, error } = await admin.auth.admin.createUser({
    email: input.email,
    password: input.password,
    email_confirm: true,
    user_metadata: { display_name: input.displayName ?? null },
  });

  if (error || !data.user) {
    return { ok: false, error: error?.message ?? "Could not create user" };
  }

  // The trigger inserts a default 'user' profile; align role/tier here.
  const { error: profileError } = await admin
    .from("profiles")
    .update({
      role: input.role,
      subscription_tier: input.subscriptionTier,
      display_name: input.displayName ?? null,
    })
    .eq("id", data.user.id);

  if (profileError) {
    return { ok: false, error: profileError.message };
  }

  revalidatePath("/users");
  return { ok: true };
}

export async function updateUserStatus(
  userId: string,
  status: UserStatus,
): Promise<ActionResult> {
  await requireAdmin();
  const admin = createAdminClient();

  const { error } = await admin
    .from("profiles")
    .update({ status })
    .eq("id", userId);

  if (error) return { ok: false, error: error.message };
  revalidatePath("/users");
  return { ok: true };
}

export async function updateUserRole(
  userId: string,
  role: UserRole,
): Promise<ActionResult> {
  await requireAdmin();
  const admin = createAdminClient();

  const { error } = await admin
    .from("profiles")
    .update({ role })
    .eq("id", userId);

  if (error) return { ok: false, error: error.message };
  revalidatePath("/users");
  return { ok: true };
}
