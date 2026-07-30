// Edge Function: issue-audio-license
//
// Same contract as issue-playback-license but for the audios table.
// Audio renditions are a single bitrate (no quality ladder), so this
// returns one signed URL rather than a list.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { handlePreflight, jsonResponse } from "../_shared/cors.ts";
import { DEFAULT_DOWNLOAD_TTL_SECONDS, presignGet } from "../_shared/r2.ts";

const SIGNED_URL_TTL_SECONDS = DEFAULT_DOWNLOAD_TTL_SECONDS;

interface AudioRow {
  id: string;
  is_premium: boolean;
  status: string;
}

interface AssetRow {
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

  let body: { audio_id?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const audioId = body.audio_id;
  if (!audioId) {
    return jsonResponse({ error: "audio_id is required" }, 400);
  }

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

  const { data: audio, error: audioError } = await supabase
    .from("audios")
    .select("id, is_premium, status")
    .eq("id", audioId)
    .maybeSingle<AudioRow>();

  if (audioError || !audio || audio.status !== "published") {
    return jsonResponse({ error: "Audio not found" }, 404);
  }

  if (audio.is_premium) {
    // Device lock: only enforced for premium content. Free content is
    // playable by any authenticated user on any device - the lock exists
    // to stop PAID access being shared, and a free account has nothing
    // worth sharing. Mirrors register_device, which likewise only locks
    // non-free tiers.
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

    // Retreat access window: refuse playback once the user's access has
    // lapsed, enforced server-side so a device clock change can't bypass
    // it. An active entitlement (e.g. a future per-content purchase) is an
    // alternate way to unlock the same premium content.
    const { data: hasAccess } = await supabase.rpc("has_active_access", {
      p_user_id: userId,
    });

    if (hasAccess !== true) {
      const { data: entitlement } = await supabase
        .from("entitlements")
        .select("id")
        .eq("user_id", userId)
        .or(`content_id.eq.${audioId},content_id.is.null`)
        .gt("expires_at", new Date().toISOString())
        .maybeSingle();

      if (!entitlement) {
        return jsonResponse(
          { error: "No active entitlement for this audio" },
          402,
        );
      }
    }
  }

  // Prefer an HLS rendition, but fall back to a single-file MP3 (the
  // MVP upload path produces audio_mp3).
  const { data: assets, error: assetError } = await supabase
    .from("content_assets")
    .select("r2_path, asset_type")
    .eq("content_id", audioId)
    .in("asset_type", ["audio_hls", "audio_mp3"])
    .eq("status", "ready")
    .returns<Array<AssetRow & { asset_type: string }>>();

  if (assetError || !assets || assets.length === 0) {
    return jsonResponse({ error: "No playable rendition for this audio" }, 404);
  }

  const asset = assets.find((a) => a.asset_type === "audio_hls") ?? assets[0];

  const signedUrl = await presignGet(asset.r2_path, SIGNED_URL_TTL_SECONDS);

  const { data: history } = await supabase
    .from("watch_history")
    .select("progress_seconds")
    .eq("user_id", userId)
    .eq("audio_id", audioId)
    .maybeSingle();

  return jsonResponse({
    audio_id: audioId,
    url: signedUrl,
    resume_position_seconds: history?.progress_seconds ?? 0,
    expires_in_seconds: SIGNED_URL_TTL_SECONDS,
  });
});
