"use server";

import { revalidatePath } from "next/cache";
import { requireAdmin } from "@/lib/auth";
import { createAdminClient } from "@/lib/supabase/admin";
import type { ActionResult } from "./users";

export interface PopupConfig {
  popup_enabled: boolean;
  popup_start_at: string | null;
  popup_title: string | null;
  popup_body: string | null;
  popup_image_url: string | null;
}

/** Reads the singleton app_config row (the next-event pop-up). */
export async function getPopupConfig(): Promise<PopupConfig | null> {
  await requireAdmin();
  const db = createAdminClient();
  const { data } = await db
    .from("app_config")
    .select(
      "popup_enabled, popup_start_at, popup_title, popup_body, popup_image_url",
    )
    .maybeSingle<PopupConfig>();
  return data ?? null;
}

/** Updates the next-event pop-up config. */
export async function savePopupConfig(input: PopupConfig): Promise<ActionResult> {
  await requireAdmin();
  const admin = createAdminClient();

  const { error } = await admin
    .from("app_config")
    .update({
      popup_enabled: input.popup_enabled,
      popup_start_at: input.popup_start_at || null,
      popup_title: input.popup_title || null,
      popup_body: input.popup_body || null,
      popup_image_url: input.popup_image_url || null,
    })
    .eq("id", true);

  if (error) return { ok: false, error: error.message };
  revalidatePath("/settings");
  return { ok: true };
}
