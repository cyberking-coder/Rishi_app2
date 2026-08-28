"use client";

import { Upload as TusUpload } from "tus-js-client";

const TUS_ENDPOINT = "https://video.bunnycdn.com/tusupload";

/**
 * How much is sent before the offset is committed to Bunny.
 *
 * tus-js-client defaults to `Infinity`: the whole file goes in a single
 * PATCH request. That is the best case for raw throughput and the worst
 * case for an unreliable connection, because nothing is committed until
 * the request completes — drop the connection 90% through a 2GB upload
 * and all of it is sent again. On a home or office line in India that is
 * the difference between "slow" and "never finishes", and it is the most
 * likely reason an upload feels like it takes forever: not that the
 * bytes move slowly, but that they move twice.
 *
 * 16MB commits an offset roughly every minute on a 2 Mbps uplink and
 * every few seconds on a fast one. The extra HTTP round trip per chunk
 * is negligible at this size; what it buys is that a dropped connection
 * resumes from the last committed offset instead of from zero.
 */
const CHUNK_SIZE = 16 * 1024 * 1024;

/**
 * Weight given to the newest sample when smoothing the transfer rate.
 *
 * A raw instantaneous rate jumps around far too much to read — it would
 * show "12 MB/s" then "0.4 MB/s" a second later, and an ETA computed
 * from it is unusable. Low enough to settle, high enough to react when
 * the connection genuinely changes.
 */
const RATE_SMOOTHING = 0.25;

export interface BunnyTusCredentials {
  videoId: string;
  libraryId: string;
  signature: string;
  expire: number;
}

export interface UploadProgress {
  pct: number;
  uploadedBytes: number;
  totalBytes: number;
  /** Smoothed bytes per second, or null until there are two samples. */
  bytesPerSecond: number | null;
  /** Seconds left at the current rate, or null while unknown. */
  secondsRemaining: number | null;
}

/** Thrown when the admin cancels an in-flight upload, so callers can
 *  tell an abort apart from a genuine failure and stay quiet about it. */
export class UploadCancelledError extends Error {
  constructor() {
    super("Upload cancelled");
    this.name = "UploadCancelledError";
  }
}

function formatBytes(bytes: number): string {
  if (bytes >= 1024 ** 3) return `${(bytes / 1024 ** 3).toFixed(1)} GB`;
  if (bytes >= 1024 ** 2) return `${Math.round(bytes / 1024 ** 2)} MB`;
  return `${Math.round(bytes / 1024)} KB`;
}

function formatDuration(seconds: number): string {
  if (seconds < 60) return "less than a minute left";
  const minutes = Math.round(seconds / 60);
  if (minutes < 60) return `about ${minutes} min left`;
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  return rest === 0
    ? `about ${hours} hr left`
    : `about ${hours} hr ${rest} min left`;
}

/**
 * A progress line an admin can act on.
 *
 * The old one said "Uploading to Bunny… 12%" and nothing else, which
 * leaves somebody staring at a dialog with no idea whether it is stuck,
 * slow, or two minutes from done — and no way to tell whether the wait
 * is their connection or a fault. Showing the rate answers that: at
 * 1 MB/s the line is the limit and no amount of code will help; at
 * 60 KB/s something is wrong.
 */
export function formatUploadProgress(p: UploadProgress): string {
  const size = `${formatBytes(p.uploadedBytes)} / ${formatBytes(p.totalBytes)}`;
  const rate =
    p.bytesPerSecond != null ? ` · ${formatBytes(p.bytesPerSecond)}/s` : "";
  const eta =
    p.secondsRemaining != null ? ` · ${formatDuration(p.secondsRemaining)}` : "";
  return `Uploading ${p.pct}% · ${size}${rate}${eta}`;
}

/** Uploads a file straight from the browser to Bunny Stream over TUS
 *  (resumable, chunked), using a short-lived signed credential minted
 *  server-side. No R2, no proxying through our own server.
 *
 *  Pass an AbortSignal to make the upload cancellable — a large video is
 *  minutes of waiting, and without this the dialog is stuck until it
 *  finishes. */
export function uploadVideoToBunny(
  file: File,
  title: string,
  creds: BunnyTusCredentials,
  onProgress: (progress: UploadProgress) => void,
  signal?: AbortSignal,
): Promise<void> {
  return new Promise((resolve, reject) => {
    if (signal?.aborted) return reject(new UploadCancelledError());

    let lastAt = Date.now();
    let lastBytes = 0;
    let rate: number | null = null;

    const upload = new TusUpload(file, {
      endpoint: TUS_ENDPOINT,
      chunkSize: CHUNK_SIZE,
      retryDelays: [0, 1000, 3000, 5000, 10000],
      headers: {
        AuthorizationSignature: creds.signature,
        AuthorizationExpire: String(creds.expire),
        VideoId: creds.videoId,
        LibraryId: creds.libraryId,
      },
      metadata: {
        filetype: file.type || "video/mp4",
        title,
      },
      onProgress: (bytesUploaded, bytesTotal) => {
        const now = Date.now();
        const elapsed = (now - lastAt) / 1000;

        // Guard the divisor. tus can report progress twice in the same
        // millisecond, and dividing by zero would put Infinity into the
        // smoothed rate permanently.
        if (elapsed > 0.25) {
          const sample = (bytesUploaded - lastBytes) / elapsed;
          rate =
            rate == null
              ? sample
              : rate * (1 - RATE_SMOOTHING) + sample * RATE_SMOOTHING;
          lastAt = now;
          lastBytes = bytesUploaded;
        }

        onProgress({
          pct: bytesTotal > 0 ? Math.round((bytesUploaded / bytesTotal) * 100) : 0,
          uploadedBytes: bytesUploaded,
          totalBytes: bytesTotal,
          bytesPerSecond: rate,
          secondsRemaining:
            rate != null && rate > 0
              ? (bytesTotal - bytesUploaded) / rate
              : null,
        });
      },
      onError: (err) =>
        reject(signal?.aborted ? new UploadCancelledError() : err),
      onSuccess: () => resolve(),
    });

    signal?.addEventListener(
      "abort",
      () => {
        // true = also tell Bunny to discard the partial upload, so a
        // cancelled attempt doesn't leave a half-uploaded video behind.
        void upload.abort(true).catch(() => {});
        reject(new UploadCancelledError());
      },
      { once: true },
    );

    upload.start();
  });
}
