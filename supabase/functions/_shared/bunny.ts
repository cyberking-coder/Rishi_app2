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
