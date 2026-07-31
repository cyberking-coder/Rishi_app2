"use server";

import { revalidatePath } from "next/cache";
import { requireAdmin } from "@/lib/auth";
import { createAdminClient } from "@/lib/supabase/admin";
import { parseYoutubeId, youtubeThumbnail } from "@/lib/youtube";
import type { ActionResult } from "./users";

export async function createYoutubeVideo(input: {
  title: string;
  url: string;
  description?: string;
  categoryId?: string;
}): Promise<ActionResult> {
  const admin = await requireAdmin();
  const db = createAdminClient();

  if (!input.title.trim()) {
    return { ok: false, error: "Give the video a title." };
  }

  const youtubeId = parseYoutubeId(input.url.trim());
  if (!youtubeId) {
    return {
      ok: false,
      error: "That doesn't look like a YouTube link. Paste the full URL.",
    };
  }

  const { error } = await db.from("youtube_videos").insert({
    title: input.title.trim(),
    description: input.description?.trim() || null,
    youtube_url: `https://www.youtube.com/watch?v=${youtubeId}`,
    youtube_id: youtubeId,
    thumbnail_url: youtubeThumbnail(youtubeId),
    category_id: input.categoryId || null,
    created_by: admin.id,
  });

  if (error) return { ok: false, error: error.message };
  revalidatePath("/youtube");
  return { ok: true };
}

export async function setYoutubePublished(args: {
  id: string;
  isPublished: boolean;
}): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  const { error } = await db
    .from("youtube_videos")
    .update({ is_published: args.isPublished })
    .eq("id", args.id);

  if (error) return { ok: false, error: error.message };
  revalidatePath("/youtube");
  return { ok: true };
}

export async function deleteYoutubeVideo(id: string): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  const { error } = await db.from("youtube_videos").delete().eq("id", id);
  if (error) return { ok: false, error: error.message };

  revalidatePath("/youtube");
  return { ok: true };
}
