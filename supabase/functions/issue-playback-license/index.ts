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
import { fetchBunnyStatus, signBunnyPlayback } from "../_shared/bunny.ts";

const SIGNED_URL_TTL_SECONDS = DEFAULT_DOWNLOAD_TTL_SECONDS; // 10 minutes

interface VideoRow {
  id: string;
  is_premium: boolean;
  status: string;
  r2_path: string | null;
  bunny_video_id: string | null;
  bunny_status: string | null;
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
    .select("id, is_premium, status, r2_path, bunny_video_id, bunny_status")
    .eq("id", videoId)
    .maybeSingle<VideoRow>();

  if (videoError || !video || video.status !== "published") {
    return jsonResponse({ error: "Video not found" }, 404);
  }

  if (video.is_premium) {
    // Retreat access window: refuse playback once the user's access has
    // lapsed, enforced server-side so a device clock change can't bypass
    // it. Only applies to premium content - free content is playable by
    // any authenticated, non-device-locked user regardless of access
    // window. Mirrors the check in issue-audio-license.
    const { data: hasAccess } = await supabase.rpc("has_active_access", {
      p_user_id: userId,
    });

    if (hasAccess !== true) {
      // Courses are sold individually, so a user with no subscription can
      // still legitimately own this video by having bought a course that
      // teaches it.
      const { data: viaCourse } = await supabase.rpc(
        "has_media_access_via_course",
        { p_user_id: userId, p_content_type: "video", p_content_id: videoId },
      );

      if (viaCourse !== true) {
        const { data: entitlement } = await supabase
          .from("entitlements")
          .select("id")
          .eq("user_id", userId)
          .or(`content_id.eq.${videoId},content_id.is.null`)
          .gt("expires_at", new Date().toISOString())
          .maybeSingle();

        if (!entitlement) {
          return jsonResponse(
            { error: "No active entitlement for this video" },
            402,
          );
        }
      }
    }
  }

  // Bunny-backed video: Bunny holds the file and serves its own HLS
  // ladder, so there are no content_assets rows to look up. Everything
  // above this point — device lock, access window, entitlements — has
  // already run, so authorization is identical either way.
  if (video.bunny_video_id) {
    if (video.bunny_status !== "ready") {
      // Our copy of the status is only as fresh as the last time an admin
      // pressed Refresh on the Videos page — Bunny sends no webhook. So a
      // video that finished encoding long ago still reads "processing"
      // here, and refusing on that alone locks a perfectly playable video
      // behind an admin's manual action. Ask Bunny directly, and write the
      // answer back so the next viewer skips this round trip.
      const liveStatus = await fetchBunnyStatus(video.bunny_video_id);
      if (liveStatus !== video.bunny_status) {
        await supabase
          .from("videos")
          .update({ bunny_status: liveStatus })
          .eq("id", videoId);
      }

      if (liveStatus !== "ready") {
        return jsonResponse(
          {
            error: liveStatus === "failed"
              ? "This video failed to process. Please contact support."
              : "This video is still processing. Please try again shortly.",
          },
          409,
        );
      }
    }

    const playback = await signBunnyPlayback(
      video.bunny_video_id,
      SIGNED_URL_TTL_SECONDS,
    );

    const { data: bunnyHistory } = await supabase
      .from("watch_history")
      .select("progress_seconds")
      .eq("user_id", userId)
      .eq("video_id", videoId)
      .maybeSingle();

    return jsonResponse({
      video_id: videoId,
      // One adaptive stream rather than a quality list — the player picks
      // a rendition per segment, so there is nothing for the client to
      // choose between.
      qualities: [{ label: "auto", bitrate: null, url: playback.hlsUrl }],
      hls_url: playback.hlsUrl,
      resume_position_seconds: bunnyHistory?.progress_seconds ?? 0,
      expires_in_seconds: SIGNED_URL_TTL_SECONDS,
    });
  }

  // Prefer HLS renditions (the quality-ladder design), but fall back to a
  // single-file MP4. The admin upload path produces video_mp4, so without
  // this fallback every video uploaded through the dashboard 404s here —
  // the same gap that was already fixed on the audio side.
  const { data: assets, error: assetsError } = await supabase
    .from("content_assets")
    .select("resolution, bitrate, r2_path, asset_type")
    .eq("content_id", videoId)
    .in("asset_type", ["video_hls", "video_mp4"])
    .eq("status", "ready")
    .returns<Array<AssetRow & { asset_type: string }>>();

  if (assetsError || !assets || assets.length === 0) {
    return jsonResponse({ error: "No playable renditions for this video" }, 404);
  }

  // Never mix the two: an HLS manifest and a progressive MP4 aren't
  // interchangeable qualities of one stream, so return whichever family
  // is present rather than a mixed ladder the player can't reason about.
  const hls = assets.filter((a) => a.asset_type === "video_hls");
  const playable = hls.length > 0 ? hls : assets;

  const qualities = await Promise.all(
    playable.map(async (asset) => ({
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
