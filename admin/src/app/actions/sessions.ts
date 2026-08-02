"use server";

import { revalidatePath } from "next/cache";
import { requireAdmin } from "@/lib/auth";
import { createAdminClient } from "@/lib/supabase/admin";
import type { ActionResult } from "./users";

/// A join link is the whole point of the card, so it is checked rather
/// than trusted. Not checked for being Zoom specifically — a Meet or
/// Teams link works identically in the app and rejecting one would be a
/// rule with nothing behind it.
function normaliseJoinUrl(raw: string): string | null {
  const trimmed = raw.trim();
  if (!trimmed) return null;
  try {
    const url = new URL(trimmed);
    if (url.protocol !== "https:" && url.protocol !== "http:") return null;
    return url.toString();
  } catch {
    return null;
  }
}

function validate(input: {
  title: string;
  joinUrl: string;
  startsAt: string;
  durationMinutes: number;
}): { error: string } | { joinUrl: string; startsAt: string } {
  if (!input.title.trim()) return { error: "Give the session a title." };

  const joinUrl = normaliseJoinUrl(input.joinUrl);
  if (!joinUrl) {
    return { error: "Paste the full meeting link, starting with https://" };
  }

  const startsAt = new Date(input.startsAt);
  if (Number.isNaN(startsAt.getTime())) {
    return { error: "Pick a valid start date and time." };
  }

  if (!Number.isFinite(input.durationMinutes) || input.durationMinutes <= 0) {
    return { error: "Duration must be at least a minute." };
  }

  return { joinUrl, startsAt: startsAt.toISOString() };
}

export async function createLiveSession(input: {
  title: string;
  description?: string;
  joinUrl: string;
  /** ISO string; the browser converts from the admin's local time. */
  startsAt: string;
  durationMinutes: number;
  thumbnailUrl?: string;
}): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  const checked = validate(input);
  if ("error" in checked) return { ok: false, error: checked.error };

  const { error } = await db.from("live_sessions").insert({
    title: input.title.trim(),
    description: input.description?.trim() || null,
    join_url: checked.joinUrl,
    starts_at: checked.startsAt,
    duration_minutes: Math.round(input.durationMinutes),
    thumbnail_url: input.thumbnailUrl || null,
  });

  if (error) return { ok: false, error: error.message };
  revalidatePath("/sessions");
  return { ok: true };
}

export async function updateLiveSession(input: {
  id: string;
  title: string;
  description?: string;
  joinUrl: string;
  startsAt: string;
  durationMinutes: number;
  thumbnailUrl?: string | null;
}): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  const checked = validate(input);
  if ("error" in checked) return { ok: false, error: checked.error };

  const { error } = await db
    .from("live_sessions")
    .update({
      title: input.title.trim(),
      description: input.description?.trim() || null,
      join_url: checked.joinUrl,
      starts_at: checked.startsAt,
      duration_minutes: Math.round(input.durationMinutes),
      thumbnail_url: input.thumbnailUrl || null,
    })
    .eq("id", input.id);

  if (error) return { ok: false, error: error.message };

  // Deliberately does NOT clear session_reminders. Moving a session an
  // hour later must not re-send the 60-minute reminder people already
  // got — a second "starts in an hour" for the same session reads as a
  // bug, and the reschedule itself is what needs announcing, not the
  // countdown. Cancel and recreate if the reminders should run again.
  revalidatePath("/sessions");
  return { ok: true };
}

/// Cancelling keeps the row so the app can say "cancelled" on a card
/// somebody was counting on, rather than having it silently vanish.
export async function setLiveSessionStatus(args: {
  id: string;
  status: "scheduled" | "cancelled";
}): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  const { error } = await db
    .from("live_sessions")
    .update({ status: args.status })
    .eq("id", args.id);

  if (error) return { ok: false, error: error.message };
  revalidatePath("/sessions");
  return { ok: true };
}

export async function deleteLiveSession(id: string): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  const { error } = await db.from("live_sessions").delete().eq("id", id);
  if (error) return { ok: false, error: error.message };

  revalidatePath("/sessions");
  return { ok: true };
}

/// Uploaded before the session row exists, so the path is keyed on time
/// rather than on a session id we don't have yet.
export async function uploadSessionThumbnail(args: {
  fileName: string;
  contentType: string;
  base64: string;
}): Promise<{ ok: true; url: string } | { ok: false; error: string }> {
  await requireAdmin();
  const db = createAdminClient();

  const bytes = Buffer.from(args.base64, "base64");
  if (bytes.byteLength > 5 * 1024 * 1024) {
    return { ok: false, error: "Thumbnails must be under 5 MB." };
  }

  const safeName = args.fileName.replace(/[^a-zA-Z0-9._-]/g, "_");
  const path = `session/${Date.now().toString(36)}-${safeName}`;

  const { error: uploadError } = await db.storage
    .from("covers")
    .upload(path, bytes, { contentType: args.contentType, upsert: false });
  if (uploadError) return { ok: false, error: uploadError.message };

  const { data } = db.storage.from("covers").getPublicUrl(path);
  return { ok: true, url: data.publicUrl };
}
