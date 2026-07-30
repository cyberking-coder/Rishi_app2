"use server";

import { revalidatePath } from "next/cache";
import { requireAdmin } from "@/lib/auth";
import { createAdminClient } from "@/lib/supabase/admin";
import { buildObjectKey, presignGet, presignUpload } from "@/lib/r2";
import { createBunnyVideo, fetchBunnyVideo, getBunnyStatus } from "@/lib/bunny";
import { slugify } from "@/lib/utils";
import type { ContentKind, ContentStatus } from "@/lib/types";
import type { ActionResult } from "./users";

export interface CreateContentInput {
  kind: ContentKind;
  title: string;
  description?: string;
  language?: string;
  isPremium: boolean;
  // audio-only
  artist?: string;
  album?: string;
}

type CreateContentResult =
  | { ok: true; id: string }
  | { ok: false; error: string };

/** Inserts a draft video/audio row and returns its id so the client can
 *  then request a presigned upload URL for the media file. */
export async function createContent(
  input: CreateContentInput,
): Promise<CreateContentResult> {
  const admin = await requireAdmin();
  const db = createAdminClient();
  const table = input.kind === "video" ? "videos" : "audios";

  const base = {
    title: input.title,
    slug: `${slugify(input.title)}-${Date.now().toString(36)}`,
    description: input.description ?? null,
    language: input.language ?? null,
    is_premium: input.isPremium,
    status: "draft" as ContentStatus,
    created_by: admin.id,
  };

  const row =
    input.kind === "video"
      ? base
      : { ...base, artist: input.artist ?? null, album: input.album ?? null };

  const { data, error } = await db
    .from(table)
    .insert(row)
    .select("id")
    .single<{ id: string }>();

  if (error || !data) {
    return { ok: false, error: error?.message ?? "Could not create content" };
  }

  revalidatePath(input.kind === "video" ? "/videos" : "/audios");
  return { ok: true, id: data.id };
}

/** Presigns a direct-to-R2 PUT URL for a content file. */
export async function presignContentUpload(args: {
  kind: ContentKind;
  contentId: string;
  fileName: string;
  contentType: string;
}): Promise<
  { ok: true; uploadUrl: string; objectKey: string } | { ok: false; error: string }
> {
  await requireAdmin();
  try {
    const objectKey = buildObjectKey(args.kind, args.contentId, args.fileName);
    const { uploadUrl } = await presignUpload(objectKey, args.contentType);
    return { ok: true, uploadUrl, objectKey };
  } catch (e) {
    return { ok: false, error: e instanceof Error ? e.message : "Presign failed" };
  }
}

/** Records the uploaded object path and moves the row into processing. */
export async function attachUpload(args: {
  kind: ContentKind;
  contentId: string;
  objectKey: string;
}): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();
  const table = args.kind === "video" ? "videos" : "audios";

  const { error } = await db
    .from(table)
    .update({ r2_path: args.objectKey, status: "processing" })
    .eq("id", args.contentId);

  if (error) return { ok: false, error: error.message };

  // Register a ready content_assets row so the playback license functions
  // (which read content_assets, not videos.r2_path) can serve this file.
  // For the MVP the uploaded file IS the playable asset (progressive
  // mp4/mp3); a transcode pipeline would instead add HLS rendition rows.
  const assetType = args.kind === "video" ? "video_mp4" : "audio_mp3";
  const { error: assetError } = await db.from("content_assets").insert({
    content_type: args.kind,
    content_id: args.contentId,
    asset_type: assetType,
    r2_path: args.objectKey,
    status: "ready",
  });
  if (assetError) return { ok: false, error: assetError.message };

  // Video also goes to Bunny Stream for transcoding into an adaptive
  // ladder. Bunny pulls it from a presigned R2 URL rather than us
  // proxying the bytes. The R2 copy stays as the fallback source, so a
  // Bunny failure degrades to the original single-file playback rather
  // than losing the upload.
  if (args.kind === "video") {
    try {
      const { data: video } = await db
        .from("videos")
        .select("title")
        .eq("id", args.contentId)
        .maybeSingle<{ title: string }>();

      const bunnyId = await createBunnyVideo(video?.title ?? "Untitled");
      // Long TTL: Bunny has to download the whole file, which for a large
      // lesson can take well past a normal playback-length signature.
      const sourceUrl = await presignGet(args.objectKey, 3600);
      await fetchBunnyVideo(bunnyId, sourceUrl);

      await db
        .from("videos")
        .update({ bunny_video_id: bunnyId, bunny_status: "processing" })
        .eq("id", args.contentId);
    } catch (e) {
      // Non-fatal: the upload itself succeeded and R2 playback still
      // works. Surfacing this as an error would imply the upload failed.
      console.error("Bunny handoff failed:", e);
      await db
        .from("videos")
        .update({ bunny_status: "failed" })
        .eq("id", args.contentId);
    }
  }

  revalidatePath(args.kind === "video" ? "/videos" : "/audios");
  return { ok: true };
}

/** Polls Bunny for encode progress. Called from the Videos page, since
 *  Bunny has no webhook configured — transcoding finishes on its own
 *  schedule and nothing pushes us the result. */
export async function refreshBunnyStatus(
  videoId: string,
): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  const { data: video } = await db
    .from("videos")
    .select("bunny_video_id")
    .eq("id", videoId)
    .maybeSingle<{ bunny_video_id: string | null }>();

  if (!video?.bunny_video_id) {
    return { ok: false, error: "This video isn't on Bunny Stream." };
  }

  try {
    const status = await getBunnyStatus(video.bunny_video_id);
    await db
      .from("videos")
      .update({ bunny_status: status })
      .eq("id", videoId);
  } catch (e) {
    return {
      ok: false,
      error: e instanceof Error ? e.message : "Could not reach Bunny",
    };
  }

  revalidatePath("/videos");
  return { ok: true };
}

/** Uploads a cover image to the public `covers` bucket and stores its URL on
 *  the content row (audios.cover_art_url / videos.thumbnail_url). The image is
 *  passed as base64 since cover files are small. */
export async function uploadCover(args: {
  kind: ContentKind;
  contentId: string;
  fileName: string;
  contentType: string;
  base64: string;
}): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  const ext = args.fileName.includes(".")
    ? args.fileName.split(".").pop()
    : "jpg";
  const path = `${args.kind}/${args.contentId}/cover.${ext}`;
  const bytes = Buffer.from(args.base64, "base64");

  const { error: uploadError } = await db.storage
    .from("covers")
    .upload(path, bytes, { contentType: args.contentType, upsert: true });
  if (uploadError) return { ok: false, error: uploadError.message };

  const { data } = db.storage.from("covers").getPublicUrl(path);
  const column = args.kind === "video" ? "thumbnail_url" : "cover_art_url";
  const table = args.kind === "video" ? "videos" : "audios";

  const { error: updateError } = await db
    .from(table)
    .update({ [column]: data.publicUrl })
    .eq("id", args.contentId);
  if (updateError) return { ok: false, error: updateError.message };

  revalidatePath(args.kind === "video" ? "/videos" : "/audios");
  return { ok: true };
}

export async function updateContentStatus(args: {
  kind: ContentKind;
  contentId: string;
  status: ContentStatus;
}): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();
  const table = args.kind === "video" ? "videos" : "audios";

  const { error } = await db
    .from(table)
    .update({ status: args.status })
    .eq("id", args.contentId);

  if (error) return { ok: false, error: error.message };
  revalidatePath(args.kind === "video" ? "/videos" : "/audios");
  return { ok: true };
}

export async function setContentPremium(args: {
  kind: ContentKind;
  contentId: string;
  isPremium: boolean;
}): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();
  const table = args.kind === "video" ? "videos" : "audios";

  const { error } = await db
    .from(table)
    .update({ is_premium: args.isPremium })
    .eq("id", args.contentId);

  if (error) return { ok: false, error: error.message };
  revalidatePath(args.kind === "video" ? "/videos" : "/audios");
  return { ok: true };
}

export async function deleteContent(args: {
  kind: ContentKind;
  contentId: string;
}): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();
  const table = args.kind === "video" ? "videos" : "audios";

  const { error } = await db.from(table).delete().eq("id", args.contentId);

  if (error) return { ok: false, error: error.message };
  revalidatePath(args.kind === "video" ? "/videos" : "/audios");
  return { ok: true };
}
