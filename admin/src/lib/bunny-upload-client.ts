"use client";

import { Upload as TusUpload } from "tus-js-client";

const TUS_ENDPOINT = "https://video.bunnycdn.com/tusupload";

export interface BunnyTusCredentials {
  videoId: string;
  libraryId: string;
  signature: string;
  expire: number;
}

/** Thrown when the admin cancels an in-flight upload, so callers can
 *  tell an abort apart from a genuine failure and stay quiet about it. */
export class UploadCancelledError extends Error {
  constructor() {
    super("Upload cancelled");
    this.name = "UploadCancelledError";
  }
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
  onProgress: (pct: number) => void,
  signal?: AbortSignal,
): Promise<void> {
  return new Promise((resolve, reject) => {
    if (signal?.aborted) return reject(new UploadCancelledError());

    const upload = new TusUpload(file, {
      endpoint: TUS_ENDPOINT,
      retryDelays: [0, 1000, 3000, 5000],
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
        onProgress(Math.round((bytesUploaded / bytesTotal) * 100));
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
