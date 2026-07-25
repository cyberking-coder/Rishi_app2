// Edge Function: issue-playback-license
//
// Validates that the calling user (a) owns an entitlement for the
// requested video and (b) is calling from their currently bound device,
// then returns a set of short-lived signed Cloudflare R2 URLs — one per
// available quality rendition — plus the user's last watch position so
// the client can resume.
//
// Deployed with: supabase functions deploy issue-playback-license

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { handlePreflight, jsonResponse } from "../_shared/cors.ts";
import { DEFAULT_DOWNLOAD_TTL_SECONDS, presignGet } from "../_shared/r2.ts";
import { RoleError, requireRole } from "../_shared/roles.ts";

const SIGNED_URL_TTL_SECONDS = DEFAULT_DOWNLOAD_TTL_SECONDS; // 10 minutes

interface VideoRow {
  id: string;
  is_premium: boolean;
  status: string;
  r2_path: string | null;
}

interface AssetRow {
  resolution: string | null;
  bitrate: number | null;
  r2_path: string;
}

Deno.serve(async (req) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: "Missing Authorization header" }, 401);
  }

  const deviceId = req.headers.get("X-Device-Id");
  if (!deviceId) {
    return jsonResponse({ error: "Missing X-Device-Id header" }, 400);
  }

  let body: { video_id?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const videoId = body.video_id;
  if (!videoId) {
    return jsonResponse({ error: "video_id is required" }, 400);
  }

  // Client scoped to the caller's JWT so RLS applies for entitlement/device checks.
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData.user) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }
  const userId = userData.user.id;

  // Retreat access window — mirrors issue-audio-license's gate. No client
  // calls this function yet (no video playback UI exists in the app), so
  // adding this check is pure hardening with no behavior change for any
  // real user today.
  try {
    await requireRole(
      supabase,
      userId,
      ["retreat_user", "admin"],
      "Your access period has ended.",
    );
  } catch (e) {
    if (e instanceof RoleError) return jsonResponse({ error: e.message }, e.status);
    throw e;
  }

  // Device check: caller must be the account's currently active device.
  const { data: device, error: deviceError } = await supabase
    .from("devices")
    .select("id, is_active")
    .eq("id", deviceId)
    .eq("user_id", userId)
    .maybeSingle();

  if (deviceError || !device || !device.is_active) {
    return jsonResponse(
      { error: "This account is already active on another device." },
      403,
    );
  }

  const { data: video, error: videoError } = await supabase
    .from("videos")
    .select("id, is_premium, status, r2_path")
    .eq("id", videoId)
    .maybeSingle<VideoRow>();

  if (videoError || !video || video.status !== "published") {
    return jsonResponse({ error: "Video not found" }, 404);
  }

  if (video.is_premium) {
    const { data: entitlement } = await supabase
      .from("entitlements")
      .select("id")
      .eq("user_id", userId)
      .or(`content_id.eq.${videoId},content_id.is.null`)
      .gt("expires_at", new Date().toISOString())
      .maybeSingle();

    if (!entitlement) {
      return jsonResponse({ error: "No active entitlement for this video" }, 402);
    }
  }

  const { data: assets, error: assetsError } = await supabase
    .from("content_assets")
    .select("resolution, bitrate, r2_path")
    .eq("content_id", videoId)
    .eq("asset_type", "video_hls")
    .eq("status", "ready")
    .returns<AssetRow[]>();

  if (assetsError || !assets || assets.length === 0) {
    return jsonResponse({ error: "No playable renditions for this video" }, 404);
  }

  const qualities = await Promise.all(
    assets.map(async (asset) => ({
      label: asset.resolution ?? "auto",
      bitrate: asset.bitrate,
      url: await presignGet(asset.r2_path, SIGNED_URL_TTL_SECONDS),
    })),
  );

  const { data: history } = await supabase
    .from("watch_history")
    .select("progress_seconds, duration_seconds")
    .eq("user_id", userId)
    .eq("video_id", videoId)
    .maybeSingle();

  return jsonResponse({
    video_id: videoId,
    qualities,
    resume_position_seconds: history?.progress_seconds ?? 0,
    expires_in_seconds: SIGNED_URL_TTL_SECONDS,
  });
});
