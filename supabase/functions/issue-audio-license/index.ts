// Edge Function: issue-audio-license
//
// Same contract as issue-playback-license but for the audios table.
// Audio renditions are a single bitrate (no quality ladder), so this
// returns one signed URL rather than a list.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { AwsClient } from "https://esm.sh/aws4fetch@1.0.17";

const SIGNED_URL_TTL_SECONDS = 600;

interface AudioRow {
  id: string;
  is_premium: boolean;
  status: string;
}

interface AssetRow {
  r2_path: string;
}

Deno.serve(async (req) => {
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

  const { data: audio, error: audioError } = await supabase
    .from("audios")
    .select("id, is_premium, status")
    .eq("id", audioId)
    .maybeSingle<AudioRow>();

  if (audioError || !audio || audio.status !== "published") {
    return jsonResponse({ error: "Audio not found" }, 404);
  }

  if (audio.is_premium) {
    const { data: entitlement } = await supabase
      .from("entitlements")
      .select("id")
      .eq("user_id", userId)
      .or(`content_id.eq.${audioId},content_id.is.null`)
      .gt("expires_at", new Date().toISOString())
      .maybeSingle();

    if (!entitlement) {
      return jsonResponse({ error: "No active entitlement for this audio" }, 402);
    }
  }

  const { data: asset, error: assetError } = await supabase
    .from("content_assets")
    .select("r2_path")
    .eq("content_id", audioId)
    .eq("asset_type", "audio_hls")
    .eq("status", "ready")
    .maybeSingle<AssetRow>();

  if (assetError || !asset) {
    return jsonResponse({ error: "No playable rendition for this audio" }, 404);
  }

  const r2 = new AwsClient({
    accessKeyId: Deno.env.get("R2_ACCESS_KEY_ID")!,
    secretAccessKey: Deno.env.get("R2_SECRET_ACCESS_KEY")!,
    service: "s3",
    region: "auto",
  });

  const bucket = Deno.env.get("R2_BUCKET")!;
  const accountId = Deno.env.get("R2_ACCOUNT_ID")!;
  const endpoint = `https://${accountId}.r2.cloudflarestorage.com`;
  const objectUrl = `${endpoint}/${bucket}/${asset.r2_path}`;

  const signed = await r2.sign(objectUrl, {
    method: "GET",
    aws: { signQuery: true },
    headers: { "X-Amz-Expires": String(SIGNED_URL_TTL_SECONDS) },
  });

  const { data: history } = await supabase
    .from("watch_history")
    .select("progress_seconds")
    .eq("user_id", userId)
    .eq("audio_id", audioId)
    .maybeSingle();

  return jsonResponse({
    audio_id: audioId,
    url: signed.url,
    resume_position_seconds: history?.progress_seconds ?? 0,
    expires_in_seconds: SIGNED_URL_TTL_SECONDS,
  });
});

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
