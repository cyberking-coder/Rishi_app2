// Shared Cloudflare R2 (S3-compatible) signing helpers.
//
// R2 credentials live ONLY in Supabase function secrets (R2_ACCESS_KEY_ID,
// R2_SECRET_ACCESS_KEY, R2_ACCOUNT_ID, R2_BUCKET). The bucket is private:
// the only way to read or write an object is a short-lived presigned URL
// minted here, server-side. Clients never see the credentials.

import { AwsClient } from "https://esm.sh/aws4fetch@1.0.17";

export const DEFAULT_DOWNLOAD_TTL_SECONDS = 600; // 10 min — playback
export const DEFAULT_UPLOAD_TTL_SECONDS = 900; // 15 min — uploads

function client(): AwsClient {
  return new AwsClient({
    accessKeyId: Deno.env.get("R2_ACCESS_KEY_ID")!,
    secretAccessKey: Deno.env.get("R2_SECRET_ACCESS_KEY")!,
    service: "s3",
    region: "auto",
  });
}

function objectUrl(r2Path: string): string {
  const accountId = Deno.env.get("R2_ACCOUNT_ID")!;
  const bucket = Deno.env.get("R2_BUCKET")!;
  // r2Path is the object key only (no bucket, no leading slash).
  return `https://${accountId}.r2.cloudflarestorage.com/${bucket}/${r2Path}`;
}

/** Presigned GET URL for streaming/downloading a private object. */
export async function presignGet(
  r2Path: string,
  ttlSeconds = DEFAULT_DOWNLOAD_TTL_SECONDS,
): Promise<string> {
  // X-Amz-Expires must live in the query string for a presigned URL — this
  // mirrors the admin dashboard's proven-working upload signer. Passing it
  // as a header produces URLs that R2 rejects with SignatureDoesNotMatch.
  const url = new URL(objectUrl(r2Path));
  url.searchParams.set("X-Amz-Expires", String(ttlSeconds));
  const signed = await client().sign(
    new Request(url, { method: "GET" }),
    { aws: { signQuery: true } },
  );
  return signed.url;
}

/**
 * Presigned PUT URL for a direct browser→R2 upload. The Content-Type is
 * pinned into the signature so the client must upload with exactly that
 * type (prevents content-type smuggling).
 */
export async function presignPut(
  r2Path: string,
  contentType: string,
  ttlSeconds = DEFAULT_UPLOAD_TTL_SECONDS,
): Promise<string> {
  const url = new URL(objectUrl(r2Path));
  url.searchParams.set("X-Amz-Expires", String(ttlSeconds));
  const signed = await client().sign(
    new Request(url, { method: "PUT", headers: { "Content-Type": contentType } }),
    { aws: { signQuery: true } },
  );
  return signed.url;
}

/** Builds the canonical object key for a content asset. */
export function buildAssetKey(args: {
  contentType: "video" | "audio";
  contentId: string;
  assetType: string;
  fileExt: string;
}): string {
  const safeExt = args.fileExt.replace(/[^a-z0-9]/gi, "").toLowerCase() || "bin";
  return `${args.contentType}/${args.contentId}/${args.assetType}.${safeExt}`;
}
