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
  expiresSeconds = 600,
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

/** Builds the storage key used for an uploaded content file. */
export function buildObjectKey(
  kind: "video" | "audio",
  id: string,
  fileName: string,
): string {
  const ext = fileName.includes(".") ? fileName.split(".").pop() : "bin";
  return `${kind}/${id}/source.${ext}`;
}
