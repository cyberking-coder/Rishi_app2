"use server";

import { revalidatePath } from "next/cache";
import { requireAdmin } from "@/lib/auth";
import { createAdminClient } from "@/lib/supabase/admin";
import type { ActionResult } from "./users";

/**
 * Resets a user's device lock: deactivates every active device for the
 * account and revokes their offline downloads, so they can register a new
 * device on next login. Used when a user gets a new phone or is locked out.
 */
export async function resetUserDevices(userId: string): Promise<ActionResult> {
  await requireAdmin();
  const admin = createAdminClient();

  // Revoke offline downloads tied to each active device first.
  const { data: devices } = await admin
    .from("devices")
    .select("id")
    .eq("user_id", userId)
    .eq("is_active", true);

  for (const device of devices ?? []) {
    await admin.rpc("revoke_downloads_for_device", {
      p_device_id: (device as { id: string }).id,
    });
  }

  const { error } = await admin
    .from("devices")
    .update({ is_active: false })
    .eq("user_id", userId)
    .eq("is_active", true);

  if (error) return { ok: false, error: error.message };

  revalidatePath("/devices");
  revalidatePath("/users");
  return { ok: true };
}

/**
 * Resets the device lock for EVERY account: revokes downloads on all active
 * devices and deactivates them, so everyone can register fresh on next login.
 * Use after shipping a new build whose device fingerprint changed.
 * Returns the number of devices that were reset.
 */
export async function resetAllDevices(): Promise<
  { ok: true; count: number } | { ok: false; error: string }
> {
  await requireAdmin();
  const admin = createAdminClient();

  const { data: devices, error: listError } = await admin
    .from("devices")
    .select("id")
    .eq("is_active", true);

  if (listError) return { ok: false, error: listError.message };

  for (const device of devices ?? []) {
    await admin.rpc("revoke_downloads_for_device", {
      p_device_id: (device as { id: string }).id,
    });
  }

  const { error } = await admin
    .from("devices")
    .update({ is_active: false })
    .eq("is_active", true);

  if (error) return { ok: false, error: error.message };

  revalidatePath("/devices");
  revalidatePath("/users");
  return { ok: true, count: devices?.length ?? 0 };
}

/** Deactivates a single device by id (finer-grained than a full reset). */
export async function deactivateDevice(deviceId: string): Promise<ActionResult> {
  await requireAdmin();
  const admin = createAdminClient();

  await admin.rpc("revoke_downloads_for_device", { p_device_id: deviceId });
  const { error } = await admin
    .from("devices")
    .update({ is_active: false })
    .eq("id", deviceId);

  if (error) return { ok: false, error: error.message };
  revalidatePath("/devices");
  return { ok: true };
}
