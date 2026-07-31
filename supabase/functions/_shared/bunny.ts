// Bunny Stream signed playback URLs.
//
// Bunny's Token Authentication v2:
//   token = "HS256-" + base64url(HMAC-SHA256(securityKey, path + expires))
// with the base64 made URL-safe ('+' -> '-', '/' -> '_', '=' stripped).
//
// The token is signed over a DIRECTORY path, not the manifest file. This
// matters: an HLS player fetches playlist.m3u8 and then dozens of .ts
// segments beneath it, so a token scoped to just the manifest would
// authorize the first request and 403 every segment after it — playback
// would start and immediately stall.
//
// Secrets: BUNNY_STREAM_TOKEN_KEY (the library's token authentication
// key) and BUNNY_STREAM_PULL_ZONE (e.g. vz-abc123.b-cdn.net).

function base64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
}

async function hmacSha256(key: string, message: string): Promise<Uint8Array> {
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(key),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    cryptoKey,
    new TextEncoder().encode(message),
  );
  return new Uint8Array(signature);
}

export interface BunnyPlayback {
  hlsUrl: string;
  expiresAt: number;
}

export async function signBunnyPlayback(
  bunnyVideoId: string,
  ttlSeconds: number,
): Promise<BunnyPlayback> {
  const securityKey = Deno.env.get("BUNNY_STREAM_TOKEN_KEY")!;
  const pullZone = Deno.env.get("BUNNY_STREAM_PULL_ZONE")!;

  const expires = Math.floor(Date.now() / 1000) + ttlSeconds;
  // Trailing slash: this is a directory prefix covering the manifest and
  // every segment under it.
  const tokenPath = `/${bunnyVideoId}/`;

  const signature = await hmacSha256(securityKey, `${tokenPath}${expires}`);
  const token = `HS256-${base64Url(signature)}`;

  const url =
    `https://${pullZone}/${bunnyVideoId}/playlist.m3u8` +
    `?token=${token}&expires=${expires}` +
    `&token_path=${encodeURIComponent(tokenPath)}`;

  return { hlsUrl: url, expiresAt: expires };
}

/// Asks Bunny what state a video is actually in.
///
/// Bunny has no webhook wired up, so `videos.bunny_status` only advances
/// when someone opens the admin Videos page and hits Refresh. A video
/// that finished encoding minutes after upload therefore stays
/// "processing" in our database indefinitely, and playback 409s even
/// though Bunny is serving it fine. Callers use this to check the real
/// state before refusing.
///
/// Requires BUNNY_STREAM_API_KEY and BUNNY_STREAM_LIBRARY_ID. Returns
/// "processing" when anything goes wrong — an unreachable Bunny is not a
/// reason to claim the encode failed.
export async function fetchBunnyStatus(
  bunnyVideoId: string,
): Promise<"processing" | "ready" | "failed"> {
  const apiKey = Deno.env.get("BUNNY_STREAM_API_KEY");
  const libraryId = Deno.env.get("BUNNY_STREAM_LIBRARY_ID");
  if (!apiKey || !libraryId) return "processing";

  try {
    const res = await fetch(
      `https://video.bunnycdn.com/library/${libraryId}/videos/${bunnyVideoId}`,
      { headers: { AccessKey: apiKey, accept: "application/json" } },
    );
    if (!res.ok) return "processing";

    const video = (await res.json()) as { status?: number };
    const status = video.status ?? 0;
    if (status === 4) return "ready";
    if (status >= 5) return "failed";
    return "processing";
  } catch (e) {
    console.error("Bunny status check failed:", e);
    return "processing";
  }
}
