"use client";

import { Upload as TusUpload } from "tus-js-client";

const TUS_ENDPOINT = "https://video.bunnycdn.com/tusupload";

export interface BunnyTusCredentials {
  videoId: string;
  libraryId: string;
  signature: string;
  expire: number;
}

/** Uploads a file straight from the browser to Bunny Stream over TUS
 *  (resumable, chunked), using a short-lived signed credential minted
 *  server-side. No R2, no proxying through our own server. */
export function uploadVideoToBunny(
  file: File,
  title: string,
  creds: BunnyTusCredentials,
  onProgress: (pct: number) => void,
): Promise<void> {
  return new Promise((resolve, reject) => {
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
      onError: (err) => reject(err),
      onSuccess: () => resolve(),
    });

    upload.start();
  });
}
