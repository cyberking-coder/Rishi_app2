/**
 * Tells an admin, before they upload, whether an audio file will scrub
 * properly on an iPhone.
 *
 * ─────────────────────────────────────────────────────────────────────
 *  WHY THIS EXISTS
 * ─────────────────────────────────────────────────────────────────────
 *  Nothing in this stack transcodes audio. `attachUpload` registers the
 *  uploaded file as the playable asset and the app streams those exact
 *  bytes, so whatever an admin exports is what a listener's phone has to
 *  seek around inside.
 *
 *  That makes the container the admin chose a real decision, and MP3 is
 *  the one container where it goes wrong. An MP3 is a bare sequence of
 *  frames with no index. To jump to 12:30, a player must work out which
 *  byte that is:
 *
 *    • Constant bitrate — arithmetic. Every frame is the same size, so
 *      the offset is a multiplication. Fast and exact.
 *    • Variable bitrate WITH a Xing/Info/VBRI header — the header
 *      carries a 100-point seek table the player interpolates. Good
 *      enough.
 *    • Variable bitrate WITHOUT one — nothing to go on. The player
 *      estimates from the average bitrate and then has to scan.
 *
 *  Android's ExoPlayer has an explicit constant-bitrate-seek fallback
 *  that papers over the third case. AVPlayer on iOS does not, which is
 *  why the same file scrubs cleanly on one platform and badly on the
 *  other. M4A/AAC sidesteps all of it: an MP4 container carries a sample
 *  table, so seeking is exact and instant everywhere.
 *
 *  So: read the first frames in the browser, say what we found, and let
 *  the admin decide. This never blocks an upload — see `inspectAudioFile`.
 */

/** What we think will happen when someone drags the scrubber. */
export type SeekQuality =
  /** Indexed container (M4A/AAC) or CBR MP3. Seeks exactly, everywhere. */
  | "good"
  /** VBR MP3 carrying a seek table. Approximate but acceptable. */
  | "acceptable"
  /** VBR MP3 with no seek table. Scrubs badly on iOS. */
  | "poor"
  /** We could not parse it. Says nothing about the file. */
  | "unknown";

export type AudioFormatReport = {
  quality: SeekQuality;
  /** One sentence for the admin. Empty when quality is "good". */
  message: string;
  /** What we actually found, for the detail line. */
  detail: string;
};

const MPEG1_BITRATES = [
  0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0,
];
const MPEG2_BITRATES = [
  0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0,
];
const SAMPLE_RATES: Record<number, number[]> = {
  3: [44100, 48000, 32000, 0], // MPEG 1
  2: [22050, 24000, 16000, 0], // MPEG 2
  0: [11025, 12000, 8000, 0], // MPEG 2.5
};

/** How much of the file to pull down. Enough for a few hundred frames,
 *  small enough that selecting a file feels instant. */
const READ_BYTES = 128 * 1024;

/** Frames to compare before calling a file constant-bitrate. A VBR
 *  encoder can emit a run of identical frames over a quiet passage —
 *  meditation audio opens quietly more often than most — so a handful is
 *  not enough to conclude anything. */
const FRAMES_TO_SCAN = 200;

type FrameHeader = {
  versionId: number;
  bitrate: number;
  sampleRate: number;
  padding: number;
  channelMode: number;
  frameLength: number;
};

/**
 * Parses an MPEG audio frame header at [offset], or returns null if
 * there isn't a valid one there.
 *
 * Validity matters more than it looks. An 0xFF byte is common in
 * compressed audio, so "found a sync word" is a weak signal on its own —
 * the reserved values below are what separate a real frame from a
 * coincidence in the middle of one.
 */
function parseFrame(b: Uint8Array, offset: number): FrameHeader | null {
  if (offset + 4 > b.length) return null;
  if (b[offset] !== 0xff || (b[offset + 1] & 0xe0) !== 0xe0) return null;

  const versionId = (b[offset + 1] >> 3) & 0x03; // 3=MPEG1, 2=MPEG2, 0=MPEG2.5
  const layer = (b[offset + 1] >> 1) & 0x03; // 1 = Layer III
  if (versionId === 1 || layer !== 1) return null; // reserved version / not Layer III

  const bitrateIndex = (b[offset + 2] >> 4) & 0x0f;
  const sampleIndex = (b[offset + 2] >> 2) & 0x03;
  if (bitrateIndex === 0 || bitrateIndex === 15) return null; // free / bad
  if (sampleIndex === 3) return null; // reserved

  const table = versionId === 3 ? MPEG1_BITRATES : MPEG2_BITRATES;
  const bitrate = table[bitrateIndex] * 1000;
  const sampleRate = SAMPLE_RATES[versionId][sampleIndex];
  if (!bitrate || !sampleRate) return null;

  const padding = (b[offset + 2] >> 1) & 0x01;
  const channelMode = (b[offset + 3] >> 6) & 0x03; // 3 = mono

  // Layer III packs 1152 samples per frame on MPEG1 and 576 on MPEG2/2.5,
  // which is where the 144 and 72 come from (samples / 8 bits).
  const coefficient = versionId === 3 ? 144 : 72;
  const frameLength =
    Math.floor((coefficient * bitrate) / sampleRate) + padding;
  if (frameLength < 4) return null;

  return { versionId, bitrate, sampleRate, padding, channelMode, frameLength };
}

/**
 * Where a Xing/Info tag sits inside a frame: immediately after the
 * header and the side-information block, whose size is fixed by version
 * and channel mode.
 */
function xingOffset(frame: FrameHeader): number {
  const mono = frame.channelMode === 3;
  if (frame.versionId === 3) return 4 + (mono ? 17 : 32); // MPEG 1
  return 4 + (mono ? 9 : 17); // MPEG 2 / 2.5
}

function tagAt(b: Uint8Array, offset: number): string {
  if (offset + 4 > b.length) return "";
  return String.fromCharCode(b[offset], b[offset + 1], b[offset + 2], b[offset + 3]);
}

/** Size of a leading ID3v2 tag, so we start looking for frames after it
 *  rather than inside someone's embedded cover art. */
function id3v2Length(b: Uint8Array): number {
  if (b.length < 10) return 0;
  if (tagAt(b, 0).slice(0, 3) !== "ID3") return 0;
  // Syncsafe integer: seven bits per byte, high bit always clear.
  const size =
    (b[6] & 0x7f) * 0x200000 +
    (b[7] & 0x7f) * 0x4000 +
    (b[8] & 0x7f) * 0x80 +
    (b[9] & 0x7f);
  const footer = (b[5] & 0x10) !== 0 ? 10 : 0;
  return 10 + size + footer;
}

/** Finds the first real frame, tolerating junk between the ID3 tag and
 *  the audio. Bounded so a non-MPEG file fails fast instead of walking
 *  the whole buffer. */
function findFirstFrame(b: Uint8Array, from: number): number {
  const limit = Math.min(b.length - 4, from + 64 * 1024);
  for (let i = from; i < limit; i++) {
    const frame = parseFrame(b, i);
    if (!frame) continue;
    // Confirm with the NEXT frame. A single valid-looking header inside
    // compressed data is a coincidence; two in a row at the predicted
    // distance is a stream.
    if (parseFrame(b, i + frame.frameLength)) return i;
  }
  return -1;
}

function analyseMp3(bytes: Uint8Array): AudioFormatReport {
  const start = findFirstFrame(bytes, id3v2Length(bytes));
  if (start < 0) {
    return {
      quality: "unknown",
      message: "",
      detail: "Could not read the MPEG frames in this file.",
    };
  }

  const first = parseFrame(bytes, start)!;

  // A Xing or Info tag lives in the first frame. "Info" is what encoders
  // write for constant bitrate, "Xing" for variable — both carry the
  // seek table that makes the difference.
  const xing = tagAt(bytes, start + xingOffset(first));
  const vbri = tagAt(bytes, start + 4 + 32);

  if (xing === "Info") {
    return {
      quality: "good",
      message: "",
      detail: `Constant bitrate MP3, ${Math.round(first.bitrate / 1000)} kbps.`,
    };
  }
  if (xing === "Xing" || vbri === "VBRI") {
    return {
      quality: "acceptable",
      message:
        "This is a variable-bitrate MP3, but it carries a seek table, so scrubbing will work — just not frame-exact.",
      detail: `Variable bitrate MP3 with a ${xing === "Xing" ? "Xing" : "VBRI"} header.`,
    };
  }

  // No header. Walk the frames: identical bitrates throughout means CBR
  // written by an encoder that simply didn't bother with an Info tag,
  // which seeks fine. Varying bitrates mean VBR with nothing to seek by.
  let offset = start;
  let scanned = 0;
  const seen = new Set<number>();
  while (scanned < FRAMES_TO_SCAN) {
    const frame = parseFrame(bytes, offset);
    if (!frame) break;
    seen.add(frame.bitrate);
    offset += frame.frameLength;
    scanned++;
  }

  if (scanned < 2) {
    return {
      quality: "unknown",
      message: "",
      detail: "Could not read enough frames to tell.",
    };
  }

  if (seen.size === 1) {
    return {
      quality: "good",
      message: "",
      detail: `Constant bitrate MP3, ${Math.round(first.bitrate / 1000)} kbps (no Info tag, ${scanned} frames checked).`,
    };
  }

  return {
    quality: "poor",
    message:
      "This is a variable-bitrate MP3 with no seek table. It will play fine, but dragging the progress bar will be slow and inaccurate on iPhones. Export as M4A/AAC, or as a constant-bitrate MP3, and this goes away.",
    detail: `Variable bitrate MP3, no Xing/Info/VBRI header (${scanned} frames checked, ${seen.size} different bitrates).`,
  };
}

/** Containers that carry a sample table, so seeking is exact by design. */
const INDEXED_EXTENSIONS = ["m4a", "m4b", "mp4", "aac", "caf", "wav", "flac"];

function extensionOf(name: string): string {
  const dot = name.lastIndexOf(".");
  return dot < 0 ? "" : name.slice(dot + 1).toLowerCase();
}

/**
 * Inspects [file] and reports how it will seek.
 *
 * Never throws and never rejects. A failure here must not stop someone
 * publishing a meditation — the report is advice, and "unknown" is an
 * honest answer that leaves the upload alone.
 */
export async function inspectAudioFile(file: File): Promise<AudioFormatReport> {
  try {
    const ext = extensionOf(file.name);

    if (INDEXED_EXTENSIONS.includes(ext)) {
      return {
        quality: "good",
        message: "",
        detail: `${ext.toUpperCase()} — an indexed container, so seeking is exact.`,
      };
    }

    if (ext !== "mp3") {
      return {
        quality: "unknown",
        message: "",
        detail: ext ? `Unrecognised format (.${ext}).` : "Unrecognised format.",
      };
    }

    // Two reads, because a leading ID3v2 tag with embedded cover art is
    // routinely bigger than READ_BYTES — and every one of these uploads
    // has cover art. Reading a fixed window from byte zero would land
    // entirely inside the artwork and find no frames at all. So: read
    // the 10-byte tag header, learn how long the tag is, and start the
    // real read after it.
    const preamble = new Uint8Array(await file.slice(0, 10).arrayBuffer());
    const skip = id3v2Length(preamble);
    const head = await file.slice(skip, skip + READ_BYTES).arrayBuffer();
    return analyseMp3(new Uint8Array(head));
  } catch {
    return {
      quality: "unknown",
      message: "",
      detail: "Could not read this file.",
    };
  }
}
