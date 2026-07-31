// Bunny Stream signed playback URLs.
//
// Bunny's advanced ("HS256-") token authentication:
//
//   token = "HS256-" + base64url(
//     HMAC-SHA256(securityKey, signaturePath + expires + signingData))
//
// where signingData is every token_* parameter, sorted by key, joined as
// raw `key=value` pairs — so token_path is part of the signed message,
// not merely a parameter travelling next to it. The base64 is made
// URL-safe ('+' -> '-', '/' -> '_', '=' stripped).
//
// The token is signed over a DIRECTORY path, not the manifest file. This
// matters: an HLS player fetches playlist.m3u8 and then dozens of .ts
// segments beneath it, so a token scoped to just the manifest would
// authorize the first request and 403 every segment after it — playback
// would start and immediately stall. For the same reason the token is
// carried in the URL path (/bcdn_token=…) rather than the query string:
// segment URLs inside a manifest are relative, so only a path prefix is
// inherited by them.
//
// This mirrors bunny.net's own signer at
// github.com/BunnyWay/BunnyCDN.TokenAuthentication (nodejs/token.js);
// the output was checked against it byte-for-byte.
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
  /** Whether a token was attached. Decides how to read a 403: with a
   *  token it's a signature or key mismatch, without one it means the
   *  CDN is still demanding a token nobody is sending. */
  signed: boolean;
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
  const unsigned = `https://${pullZone}/${bunnyVideoId}/playlist.m3u8`;

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
    return { hlsUrl: unsigned, expiresAt: expires, signed: false };
  }

  // Trailing slash: this is a directory prefix covering the manifest and
  // every segment under it.
  const tokenPath = `/${bunnyVideoId}/`;

  // token_path is part of what gets signed, not just a query parameter
  // alongside the signature. Bunny folds every token_* parameter into the
  // HMAC message, sorted by key, as raw (un-encoded) `key=value` pairs.
  // Omitting it — as this did — produces a signature Bunny computes
  // differently and rejects with a 403 on every request.
  const signingData = `token_path=${tokenPath}`;
  const signature = await hmacSha256(
    securityKey,
    `${tokenPath}${expires}${signingData}`,
  );
  const token = `HS256-${base64Url(signature)}`;

  // Directory tokens go in the PATH, not the query string. An HLS
  // manifest lists its segments as relative URLs, so the player resolves
  // them against the manifest's directory — a token in the query string
  // is dropped the moment the player asks for the first .ts segment, and
  // playback dies a second or two in. Carrying it as a path prefix means
  // every segment request inherits it for free.
  const url =
    `https://${pullZone}/bcdn_token=${token}` +
    `&token_path=${encodeURIComponent(tokenPath)}` +
    `&expires=${expires}` +
    `/${bunnyVideoId}/playlist.m3u8`;

  return { hlsUrl: url, expiresAt: expires, signed: true };
}

/// Confirms the CDN will actually serve this manifest.
///
/// Without it, every misconfiguration — wrong pull zone hostname, a
/// token the pull zone rejects, an encode that hasn't produced a
/// playlist yet — reaches the phone as the same opaque ExoPlayer
/// "Source error", which says nothing about which of those it was.
/// Returns null when the manifest is fine, or a human-readable reason.
/// The first media URI in an HLS playlist — the line after a #EXT-X-
/// tag that isn't itself a tag. Returns null for a playlist with no
/// entries at all.
function firstPlaylistUri(body: string): string | null {
  for (const raw of body.split("\n")) {
    const line = raw.trim();
    if (line.length === 0 || line.startsWith("#")) continue;
    return line;
  }
  return null;
}

export async function checkBunnyManifest(
  url: string,
  signed: boolean,
): Promise<string | null> {
  try {
    // GET, not HEAD: CDNs are inconsistent about HEAD on cached objects,
    // and a manifest is a few hundred bytes.
    const res = await fetch(url, { headers: { accept: "*/*" } });

    if (res.ok) {
      // A 200 isn't proof of a playlist — a CDN error page, or a zone
      // serving something other than this video, arrives with the same
      // status. Every HLS manifest starts with #EXTM3U, so check for it
      // rather than trusting the code alone.
      const body = await res.text();
      if (!body.trimStart().startsWith("#EXTM3U")) {
        return "The video CDN returned something that isn't an HLS " +
          "playlist. Check that BUNNY_STREAM_PULL_ZONE names this " +
          "library's own pull zone.";
      }

      // The master playlist passing means nothing on its own. A player
      // immediately follows it to a rendition playlist, and with a
      // path-embedded token that second request only carries the token
      // if the reference is relative — an absolute one resolves against
      // the domain root and loses the whole /bcdn_token=…/ prefix. That
      // failure reaches the phone as a 403 while this check, which only
      // ever looked at the master, reported everything fine.
      const rendition = firstPlaylistUri(body);
      if (rendition) {
        const child = new URL(rendition, url).toString();
        const childRes = await fetch(child, { headers: { accept: "*/*" } });
        await childRes.body?.cancel();
        if (childRes.status === 403) {
          return "Bunny served the playlist but rejected the video's " +
            "renditions (403). The playback token doesn't survive the " +
            "jump from the master playlist, so token authentication on " +
            "this pull zone can't be used with a native player — turn " +
            "it off, or unset BUNNY_STREAM_TOKEN_KEY to serve unsigned " +
            "URLs.";
        }
        if (!childRes.ok) {
          return `Bunny returned ${childRes.status} for this video's ` +
            `renditions.`;
        }
      }
      return null;
    }

    // Drain the body so the connection can be reused rather than reset.
    await res.body?.cancel();

    if (res.status === 403) {
      // Same status, opposite causes — and blaming the key when no key
      // was used sends you to a setting that is already correct.
      return signed
        ? "Bunny rejected the playback token (403). Check " +
          "BUNNY_STREAM_TOKEN_KEY against the pull zone's Token " +
          "Authentication key."
        : "Bunny refused an unsigned request (403), so something is " +
          "still requiring a token. Check Stream > your library > " +
          "Security for 'Token authentication' AND 'Block direct URL " +
          "file access' - the pull zone's own toggle is not the only " +
          "one.";
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
