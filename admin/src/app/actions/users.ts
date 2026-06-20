"use server";

import { revalidatePath } from "next/cache";
import { requireAdmin } from "@/lib/auth";
import { createAdminClient } from "@/lib/supabase/admin";
import type { UserRole, UserStatus } from "@/lib/types";

/** Default retreat access window, in days, granted to a new attendee. */
const DEFAULT_ACCESS_DAYS = 30;

export interface CreateUserInput {
  email: string;
  password: string;
  displayName?: string;
  role: UserRole;
  subscriptionTier: string;
  /** Length of the access window in days. Defaults to 30. Use 0 for no limit
   *  (e.g. staff accounts). */
  accessDays?: number;
}

export type ActionResult = { ok: true } | { ok: false; error: string };

/** Creates an auth user (service role) and sets their profile role/tier and
 *  retreat access window. The profile row itself is auto-created by the
 *  `handle_new_user` trigger. */
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

  const days = input.accessDays ?? DEFAULT_ACCESS_DAYS;
  const now = new Date();
  const accessExpiresAt =
    days > 0
      ? new Date(now.getTime() + days * 24 * 60 * 60 * 1000).toISOString()
      : null; // null == unlimited access

  // The trigger inserts a default 'user' profile; align role/tier + access.
  const { error: profileError } = await admin
    .from("profiles")
    .update({
      role: input.role,
      subscription_tier: input.subscriptionTier,
      display_name: input.displayName ?? null,
      access_started_at: now.toISOString(),
      access_expires_at: accessExpiresAt,
    })
    .eq("id", data.user.id);

  if (profileError) {
    return { ok: false, error: profileError.message };
  }

  revalidatePath("/users");
  return { ok: true };
}

/** Sets a user's access window to expire [days] from now (0 = unlimited).
 *  Use to extend an attendee or revoke early. */
export async function setUserAccessDays(
  userId: string,
  days: number,
): Promise<ActionResult> {
  await requireAdmin();
  const admin = createAdminClient();

  const expiresAt =
    days > 0
      ? new Date(Date.now() + days * 24 * 60 * 60 * 1000).toISOString()
      : null;

  const { error } = await admin
    .from("profiles")
    .update({ access_expires_at: expiresAt })
    .eq("id", userId);

  if (error) return { ok: false, error: error.message };
  revalidatePath("/users");
  return { ok: true };
}

/** Sets a user's access to expire [minutes] from now. Handy for testing the
 *  expiry flow without waiting days (e.g. 5–10 minutes). */
export async function setUserAccessMinutes(
  userId: string,
  minutes: number,
): Promise<ActionResult> {
  await requireAdmin();
  const admin = createAdminClient();

  const expiresAt = new Date(Date.now() + minutes * 60 * 1000).toISOString();

  const { error } = await admin
    .from("profiles")
    .update({ access_expires_at: expiresAt })
    .eq("id", userId);

  if (error) return { ok: false, error: error.message };
  revalidatePath("/users");
  return { ok: true };
}

/** Immediately ends a user's access (sets expiry to now). Their audio
 *  disappears and downloads are purged on next app open. */
export async function revokeUserAccess(userId: string): Promise<ActionResult> {
  await requireAdmin();
  const admin = createAdminClient();

  const { error } = await admin
    .from("profiles")
    .update({ access_expires_at: new Date().toISOString() })
    .eq("id", userId);

  if (error) return { ok: false, error: error.message };
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
