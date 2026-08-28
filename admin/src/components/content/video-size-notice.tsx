"use client";

/**
 * Tells the person uploading when the file itself is the reason the
 * upload will be slow.
 *
 * Nothing in the transfer can be made faster than the line it goes over.
 * The bytes go straight from this browser to Bunny with nothing in
 * between, so once the connection is saturated the only remaining lever
 * is how many bytes there are — and that lever is usually enormous. A
 * 1080p H.264 export of a one-hour talk is around 1.5 GB; the same talk
 * straight out of a camera or an editor's master preset can be 8 GB or
 * more. That is a five-fold difference in waiting, decided before the
 * upload starts.
 *
 * It matters more here than it would elsewhere because Bunny re-encodes
 * everything on arrival. The extra size buys nothing at all: the
 * renditions members actually stream are generated from the upload and
 * are no better for having been made from a larger master.
 *
 * Advisory only. It never blocks an upload — sometimes the big file is
 * the only file there is.
 */
const GENTLE_MB = 2 * 1024; // 2 GB — worth a word
const LOUD_MB = 5 * 1024; // 5 GB — worth stopping to re-export

export function VideoSizeNotice({ file }: { file: File | null }) {
  if (!file) return null;

  const mb = file.size / (1024 * 1024);
  if (mb < GENTLE_MB) return null;

  const loud = mb >= LOUD_MB;
  const size =
    mb >= 1024 ? `${(mb / 1024).toFixed(1)} GB` : `${Math.round(mb)} MB`;

  return (
    <div
      className={`rounded-md border p-3 text-sm ${
        loud
          ? "border-amber-300 bg-amber-50 text-amber-900"
          : "border-slate-200 bg-slate-50 text-slate-700"
      }`}
    >
      <p className="font-medium">This file is {size}</p>
      <p className="mt-1">
        {loud
          ? "That is large enough to take hours on a typical connection. Bunny re-encodes everything on arrival, so a 1080p H.264 export would look identical to viewers and upload several times faster."
          : "Uploads go straight from this browser to Bunny, so the time this takes is mostly your upload speed. Bunny re-encodes on arrival — a 1080p H.264 export uploads faster and looks the same to viewers."}
      </p>
      <p className="mt-2 text-xs opacity-70">
        You can upload it as it is. Leave this tab open until it finishes.
      </p>
    </div>
  );
}
