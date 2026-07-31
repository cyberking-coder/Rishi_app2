import "server-only";
import { AwsClient } from "aws4fetch";
import { env } from "@/lib/env";

/**
 * Generates a presigned PUT URL so the admin's browser can upload a content
 * file straight to Cloudflare R2 without the bytes passing through our
 * server. Mirrors the signing approach used by the playback edge functions.
 */
export async function presignUpload(
  objectKey: string,
  contentType: string,
  expiresSeconds = 3600,
): Promise<{ uploadUrl: string; objectKey: string }> {
  const r2 = env.r2();
  const client = new AwsClient({
    accessKeyId: r2.accessKeyId,
    secretAccessKey: r2.secretAccessKey,
    service: "s3",
    region: "auto",
  });

  const endpoint = `https://${r2.accountId}.r2.cloudflarestorage.com/${r2.bucket}/${objectKey}`;
  const url = new URL(endpoint);
  url.searchParams.set("X-Amz-Expires", String(expiresSeconds));

  const signed = await client.sign(
    new Request(url, { method: "PUT", headers: { "content-type": contentType } }),
    { aws: { signQuery: true } },
  );

  return { uploadUrl: signed.url, objectKey };
}

/**
 * Generates a presigned GET URL for an object already in R2, so an
 * external service (Bunny Stream) can pull the file itself rather than
 * us proxying the bytes through our server.
 */
export async function presignGet(
  objectKey: string,
  expiresSeconds = 3600,
): Promise<string> {
  const r2 = env.r2();
  const client = new AwsClient({
    accessKeyId: r2.accessKeyId,
    secretAccessKey: r2.secretAccessKey,
    service: "s3",
    region: "auto",
  });

  const endpoint = `https://${r2.accountId}.r2.cloudflarestorage.com/${r2.bucket}/${objectKey}`;
  const url = new URL(endpoint);
  url.searchParams.set("X-Amz-Expires", String(expiresSeconds));

  const signed = await client.sign(new Request(url, { method: "GET" }), {
    aws: { signQuery: true },
  });

  return signed.url;
}

/**
 * Deletes an object from R2. Used to clear the staging copy of a video
 * once Bunny Stream has confirmed it has the file and it's playable —
 * from that point on playback never reads r2_path for a Bunny-backed
 * video, so keeping the R2 copy around is pure storage cost.
 */
export async function deleteObject(objectKey: string): Promise<void> {
  const r2 = env.r2();
  const client = new AwsClient({
    accessKeyId: r2.accessKeyId,
    secretAccessKey: r2.secretAccessKey,
    service: "s3",
    region: "auto",
  });

  const endpoint = `https://${r2.accountId}.r2.cloudflarestorage.com/${r2.bucket}/${objectKey}`;
  const res = await client.fetch(endpoint, { method: "DELETE" });
  if (!res.ok && res.status !== 404) {
    throw new Error(`R2 delete failed (${res.status})`);
  }
}

/** Builds the storage key used for an uploaded content file. */
export function buildObjectKey(
  kind: "video" | "audio",
  id: string,
  fileName: string,
): string {
  const ext = fileName.includes(".") ? fileName.split(".").pop() : "bin";
  return `${kind}/${id}/source.${ext}`;
}
