// Edge Function: issue-upload-url
//
// The secure upload API. Admin-only. Mints a short-lived presigned R2 PUT
// URL so an admin's browser can upload a content file DIRECTLY to the
// private bucket (bytes never transit Supabase or our app server), and
// registers a content_assets row to track it.
//
// Two actions (POST body `action`):
//   "presign"  (default) → create a pending content_assets row + PUT URL
//   "complete"           → mark the asset ready (call after the PUT 200s)
//
// R2 credentials live only in this function's secrets. Deployed with:
//   supabase functions deploy issue-upload-url

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { handlePreflight, jsonResponse } from "../_shared/cors.ts";
import {
  buildAssetKey,
  DEFAULT_UPLOAD_TTL_SECONDS,
  presignPut,
} from "../_shared/r2.ts";

const ADMIN_ROLES = ["admin", "content_manager"];

// Keep in step with the content_assets.asset_type CHECK constraint —
// see supabase/migrations/20260826000001_allow_audio_m4a_asset.sql.
const VALID_ASSET_TYPES = new Set([
  "video_hls", "video_mp4", "audio_hls", "audio_mp3", "audio_m4a",
  "poster", "thumbnail", "trailer", "subtitle",
]);

interface PresignBody {
  action?: "presign";
  content_type: "video" | "audio";
  content_id: string;
  asset_type: string;
  file_ext: string;
  file_content_type: string;
  resolution?: string;
  bitrate?: number;
}

interface CompleteBody {
  action: "complete";
  asset_id: string;
  bytes?: number;
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

  // User-scoped client so RLS + the admin role check apply to the caller.
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData.user) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  // Admin gate.
  const { data: profile } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", userData.user.id)
    .maybeSingle<{ role: string }>();

  if (!profile || !ADMIN_ROLES.includes(profile.role)) {
    return jsonResponse({ error: "Forbidden" }, 403);
  }

  let body: PresignBody | CompleteBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  if (body.action === "complete") {
    return await complete(supabase, body);
  }
  return await presign(supabase, body as PresignBody);
});

async function presign(
  supabase: ReturnType<typeof createClient>,
  body: PresignBody,
): Promise<Response> {
  if (
    !body.content_id ||
    (body.content_type !== "video" && body.content_type !== "audio") ||
    !VALID_ASSET_TYPES.has(body.asset_type) ||
    !body.file_content_type ||
    !body.file_ext
  ) {
    return jsonResponse({ error: "Missing or invalid upload fields" }, 400);
  }

  const r2Path = buildAssetKey({
    contentType: body.content_type,
    contentId: body.content_id,
    assetType: body.asset_type,
    fileExt: body.file_ext,
  });

  // Register the pending asset (admin RLS permits the insert).
  const { data: asset, error: insertError } = await supabase
    .from("content_assets")
    .insert({
      content_type: body.content_type,
      content_id: body.content_id,
      asset_type: body.asset_type,
      resolution: body.resolution ?? null,
      bitrate: body.bitrate ?? null,
      r2_path: r2Path,
      status: "pending",
    })
    .select("id")
    .single<{ id: string }>();

  if (insertError || !asset) {
    return jsonResponse(
      { error: insertError?.message ?? "Could not register asset" },
      400,
    );
  }

  const uploadUrl = await presignPut(r2Path, body.file_content_type);

  return jsonResponse({
    asset_id: asset.id,
    r2_path: r2Path,
    upload_url: uploadUrl,
    // The client MUST send this exact Content-Type on the PUT.
    required_content_type: body.file_content_type,
    expires_in_seconds: DEFAULT_UPLOAD_TTL_SECONDS,
  });
}

async function complete(
  supabase: ReturnType<typeof createClient>,
  body: CompleteBody,
): Promise<Response> {
  if (!body.asset_id) {
    return jsonResponse({ error: "asset_id is required" }, 400);
  }

  const { error } = await supabase
    .from("content_assets")
    .update({ status: "ready", bytes: body.bytes ?? null })
    .eq("id", body.asset_id);

  if (error) return jsonResponse({ error: error.message }, 400);
  return jsonResponse({ ok: true, asset_id: body.asset_id });
}
