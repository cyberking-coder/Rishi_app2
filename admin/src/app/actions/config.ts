"use server";

import { revalidatePath } from "next/cache";
import { requireAdmin } from "@/lib/auth";
import { createAdminClient } from "@/lib/supabase/admin";
import type { ActionResult } from "./users";
import { shrinkImage } from "@/lib/image";

/** One scheduled pop-up. `weekday` is ISO-8601: 1 = Monday … 7 = Sunday,
 *  null = every day. */
export interface AppPopup {
  id: string;
  title: string | null;
  body: string | null;
  image_url: string | null;
  weekday: number | null;
  starts_at: string | null;
  enabled: boolean;
  sort_order: number;
  /** In-app route the button opens, e.g. '/watch'. Null = no button. */
  cta_route: string | null;
  cta_label: string | null;
}

export type PopupDraft = Omit<AppPopup, "id"> & { id?: string };

/** Every pop-up, in the order the app evaluates them — first match for
 *  today wins. */
export async function listPopups(): Promise<AppPopup[]> {
  await requireAdmin();
  const db = createAdminClient();
  const { data } = await db
    .from("app_popups")
    .select(
      "id, title, body, image_url, weekday, starts_at, enabled, sort_order, " +
        "cta_route, cta_label",
    )
    .order("sort_order", { ascending: true })
    .returns<AppPopup[]>();
  return data ?? [];
}

/** Uploads a pop-up image and returns the public URL.
 *
 *  The path carries the pop-up's own id. The single-pop-up version wrote
 *  everything to `popup/cover.<ext>`, which with more than one pop-up
 *  would mean each upload silently replacing the previous one's artwork. */
export async function uploadPopupImage(
  base64: string,
  mimeType: string,
  ext: string,
  popupKey: string,
): Promise<{ ok: true; url: string } | { ok: false; error: string }> {
  await requireAdmin();
  const admin = createAdminClient();

  const shrunk = await shrinkImage(
    Buffer.from(base64, "base64"),
    mimeType,
    ext,
  );
  const path = `popup/${popupKey}.${shrunk.ext}`;

  const { error } = await admin.storage
    .from("covers")
    .upload(path, shrunk.bytes, {
      contentType: shrunk.contentType,
      upsert: true,
    });

  if (error) return { ok: false, error: error.message };

  const { data } = admin.storage.from("covers").getPublicUrl(path);
  // Cache-busted. The path is stable per pop-up, so replacing an image
  // without this leaves every device showing the old one from cache.
  return { ok: true, url: `${data.publicUrl}?v=${Date.now()}` };
}

/** Creates or updates one pop-up. */
export async function savePopup(input: PopupDraft): Promise<ActionResult> {
  await requireAdmin();
  const admin = createAdminClient();

  const row = {
    title: input.title || null,
    body: input.body || null,
    image_url: input.image_url || null,
    weekday: input.weekday ?? null,
    starts_at: input.starts_at || null,
    enabled: input.enabled,
    sort_order: input.sort_order,
    cta_route: input.cta_route || null,
    cta_label: input.cta_label || null,
  };

  const { error } = input.id
    ? await admin.from("app_popups").update(row).eq("id", input.id)
    : await admin.from("app_popups").insert(row);

  if (error) return { ok: false, error: error.message };

  revalidatePath("/settings");
  return { ok: true };
}

export async function deletePopup(id: string): Promise<ActionResult> {
  await requireAdmin();
  const admin = createAdminClient();

  const { error } = await admin.from("app_popups").delete().eq("id", id);
  if (error) return { ok: false, error: error.message };

  revalidatePath("/settings");
  return { ok: true };
}
