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

export class BunnyConfigError extends Error {}

export async function signBunnyPlayback(
  bunnyVideoId: string,
  ttlSeconds: number,
): Promise<BunnyPlayback> {
  const pullZone = Deno.env.get("BUNNY_STREAM_PULL_ZONE");
  const securityKey = Deno.env.get("BUNNY_STREAM_TOKEN_KEY");

  // Was `Deno.env.get(...)!`, which doesn't assert anything at runtime —
  // an unset variable produced the string "undefined" and a URL of
  // https://undefined/<id>/playlist.m3u8. The player can't tell that
  // apart from a broken video: it just reports a source error. Fail here,
  // where the message can name the missing variable.
  if (!pullZone) {
    throw new BunnyConfigError(
      "BUNNY_STREAM_PULL_ZONE is not set on this function.",
    );
  }

  const expires = Math.floor(Date.now() / 1000) + ttlSeconds;
  const base = `https://${pullZone}/${bunnyVideoId}/playlist.m3u8`;

  // No key, no token. Signing with a missing key yields a signature that
  // is guaranteed wrong, so a pull zone with token authentication ON
  // would 403 either way — while a pull zone with it OFF (the default
  // for a new Stream library) plays the unsigned URL perfectly well.
  // Appending a bogus token can only turn the second case into a
  // failure, so don't.
  if (!securityKey) {
    console.warn(
      "BUNNY_STREAM_TOKEN_KEY is not set - serving an unsigned playback " +
        "URL. This works only while the pull zone has token " +
        "authentication disabled.",
    );
    return { hlsUrl: base, expiresAt: expires };
  }

  // Trailing slash: this is a directory prefix covering the manifest and
  // every segment under it.
  const tokenPath = `/${bunnyVideoId}/`;

  const signature = await hmacSha256(securityKey, `${tokenPath}${expires}`);
  const token = `HS256-${base64Url(signature)}`;

  const url =
    `${base}?token=${token}&expires=${expires}` +
    `&token_path=${encodeURIComponent(tokenPath)}`;

  return { hlsUrl: url, expiresAt: expires };
}

/// Confirms the CDN will actually serve this manifest.
///
/// Without it, every misconfiguration — wrong pull zone hostname, a
/// token the pull zone rejects, an encode that hasn't produced a
/// playlist yet — reaches the phone as the same opaque ExoPlayer
/// "Source error", which says nothing about which of those it was.
/// Returns null when the manifest is fine, or a human-readable reason.
export async function checkBunnyManifest(url: string): Promise<string | null> {
  try {
    // GET, not HEAD: CDNs are inconsistent about HEAD on cached objects,
    // and a manifest is a few hundred bytes.
    const res = await fetch(url, { headers: { accept: "*/*" } });
    // Drain the body so the connection can be reused rather than reset.
    await res.body?.cancel();

    if (res.ok) return null;
    if (res.status === 403) {
      return "Bunny rejected the playback token (403). Check " +
        "BUNNY_STREAM_TOKEN_KEY against the pull zone's token " +
        "authentication key.";
    }
    if (res.status === 404) {
      return "Bunny has no playlist for this video yet (404). It may " +
        "still be encoding, or BUNNY_STREAM_PULL_ZONE may be pointing " +
        "at the wrong zone.";
    }
    return `Bunny returned ${res.status} for this video's playlist.`;
  } catch (e) {
    return `Could not reach the video CDN: ${e}`;
  }
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
/// "unknown" — never "processing" — when those aren't configured or the
/// call fails, so callers can tell "Bunny says it isn't ready" apart from
/// "we couldn't ask". Conflating the two turns a missing secret into a
/// permanently unplayable video.
export type BunnyStatus = "processing" | "ready" | "failed" | "unknown";

export async function fetchBunnyStatus(
  bunnyVideoId: string,
): Promise<BunnyStatus> {
  const apiKey = Deno.env.get("BUNNY_STREAM_API_KEY");
  const libraryId = Deno.env.get("BUNNY_STREAM_LIBRARY_ID");
  if (!apiKey || !libraryId) {
    console.warn(
      "BUNNY_STREAM_API_KEY / BUNNY_STREAM_LIBRARY_ID not set - cannot " +
        "verify encode status.",
    );
    return "unknown";
  }

  try {
    const res = await fetch(
      `https://video.bunnycdn.com/library/${libraryId}/videos/${bunnyVideoId}`,
      { headers: { AccessKey: apiKey, accept: "application/json" } },
    );
    if (!res.ok) {
      console.error(`Bunny status check returned ${res.status}`);
      return "unknown";
    }

    const video = (await res.json()) as { status?: number };
    const status = video.status ?? 0;
    if (status === 4) return "ready";
    if (status >= 5) return "failed";
    return "processing";
  } catch (e) {
    console.error("Bunny status check failed:", e);
    return "unknown";
  }
}
