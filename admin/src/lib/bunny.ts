import { createHash } from "crypto";
import { env } from "./env";

const BUNNY_API = "https://video.bunnycdn.com/library";

// Bunny's upload endpoint needs the library API key, which must never
// reach a browser. Rather than proxy large video files through this
// server (or pull in a TUS client), uploads reuse the existing
// direct-to-R2 flow and then hand Bunny a short-lived presigned R2 URL
// to fetch from. R2 acts as a staging area: proven upload UI with real
// progress, no new browser dependency, and Bunny does the transfer
// server-to-server.

interface BunnyVideo {
  guid: string;
}

function headers(): HeadersInit {
  return {
    AccessKey: env.bunny().apiKey,
    "Content-Type": "application/json",
  };
}

/** Creates an empty video record and returns its Bunny guid. */
export async function createBunnyVideo(title: string): Promise<string> {
  const { libraryId } = env.bunny();
  const res = await fetch(`${BUNNY_API}/${libraryId}/videos`, {
    method: "POST",
    headers: headers(),
    body: JSON.stringify({ title }),
  });

  if (!res.ok) {
    throw new Error(`Bunny video create failed: ${res.status} ${await res.text()}`);
  }

  const video = (await res.json()) as BunnyVideo;
  return video.guid;
}

/** Tells Bunny to pull the source file from a URL and start encoding. */
export async function fetchBunnyVideo(
  bunnyVideoId: string,
  sourceUrl: string,
): Promise<void> {
  const { libraryId } = env.bunny();
  const res = await fetch(
    `${BUNNY_API}/${libraryId}/videos/${bunnyVideoId}/fetch`,
    {
      method: "POST",
      headers: headers(),
      body: JSON.stringify({ url: sourceUrl }),
    },
  );

  if (!res.ok) {
    throw new Error(`Bunny fetch failed: ${res.status} ${await res.text()}`);
  }
}

/**
 * Creates a Bunny video slot and signs a short-lived TUS upload
 * credential for it, so the admin's browser can upload the file bytes
 * straight to Bunny — no R2 staging, no server-side proxying of large
 * video files. The API key itself never leaves the server; only this
 * scoped, time-boxed signature does.
 */
export async function createBunnyTusUpload(title: string): Promise<{
  videoId: string;
  libraryId: string;
  signature: string;
  expire: number;
}> {
  const { apiKey, libraryId } = env.bunny();
  const videoId = await createBunnyVideo(title);
  const expire = Math.floor(Date.now() / 1000) + 3600;
  const signature = createHash("sha256")
    .update(`${libraryId}${apiKey}${expire}${videoId}`)
    .digest("hex");

  return { videoId, libraryId, signature, expire };
}

/** Bunny's numeric encode status, mapped to our own vocabulary.
 *  0-3 are queued/processing stages, 4 is finished, 5+ are failures. */
export async function getBunnyStatus(
  bunnyVideoId: string,
): Promise<"processing" | "ready" | "failed"> {
  const { libraryId } = env.bunny();
  const res = await fetch(`${BUNNY_API}/${libraryId}/videos/${bunnyVideoId}`, {
    headers: headers(),
  });

  if (!res.ok) return "processing";

  const video = (await res.json()) as { status?: number };
  const status = video.status ?? 0;
  if (status === 4) return "ready";
  if (status >= 5) return "failed";
  return "processing";
}
