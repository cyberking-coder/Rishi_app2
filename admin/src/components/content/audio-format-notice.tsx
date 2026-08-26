"use client";

import { useEffect, useState } from "react";

import { inspectAudioFile, type AudioFormatReport } from "@/lib/audio-format";

/**
 * Tells the person uploading whether their audio file will scrub
 * properly on an iPhone, at the moment they choose it.
 *
 * This warns; it never blocks. The check is a heuristic read of the
 * first frames, and a wrong "poor" that stopped an upload would be a far
 * worse bug than the one it is guarding against — someone would simply
 * be unable to publish. So the notice explains, and the Upload button
 * stays live.
 *
 * It is placed at the point of choosing rather than in a document
 * nobody reads because the fix is free at this moment (re-export) and
 * expensive later (re-upload, or living with it).
 */
export function AudioFormatNotice({ file }: { file: File | null }) {
  const [report, setReport] = useState<AudioFormatReport | null>(null);

  useEffect(() => {
    if (!file) {
      setReport(null);
      return;
    }

    // A file can be swapped while the previous read is still in flight;
    // without this the older result could land last and describe a file
    // that is no longer selected.
    let current = true;
    setReport(null);
    inspectAudioFile(file).then((r) => {
      if (current) setReport(r);
    });
    return () => {
      current = false;
    };
  }, [file]);

  if (!report) return null;

  // "good" and "unknown" both say nothing. Silence is right for the
  // first — there is no news — and for the second, since we have learned
  // nothing and a shrug on screen is just noise.
  if (report.quality === "good" || report.quality === "unknown") return null;

  const poor = report.quality === "poor";

  return (
    <div
      className={`rounded-md border p-3 text-sm ${
        poor
          ? "border-amber-300 bg-amber-50 text-amber-900"
          : "border-slate-200 bg-slate-50 text-slate-700"
      }`}
    >
      <p className="font-medium">
        {poor ? "This file will scrub badly on iPhones" : "Seeking will be approximate"}
      </p>
      <p className="mt-1">{report.message}</p>
      <p className="mt-1 text-xs opacity-70">{report.detail}</p>
      {poor && (
        <p className="mt-2 text-xs opacity-70">
          You can upload it anyway — playback itself is unaffected.
        </p>
      )}
    </div>
  );
}
