import sharp from "sharp";

/**
 * Shrinks an uploaded image to something a phone can actually use.
 *
 * ─────────────────────────────────────────────────────────────────────
 *  WHY THIS EXISTS
 * ─────────────────────────────────────────────────────────────────────
 *
 * Every upload action in this admin used to write the admin's chosen
 * file straight to storage, under a comment reading "passed as base64
 * since cover files are small". They are not small. The artwork brief
 * asks for phone-wallpaper dimensions, so covers arrive at 1242x2688
 * and above, and one of those is roughly 13 MB once a phone decodes it
 * — for a tile that may be drawn at 52 pixels.
 *
 * The app now decodes at display size (see RemoteImage in the Flutter
 * app), which fixes the memory and the scroll stutter. It does not fix
 * the download: a 4 MB cover is still 4 MB over a phone connection, and
 * still 4 MB of storage, forever. This closes that end.
 *
 * ─────────────────────────────────────────────────────────────────────
 *  WHY THE CAP IS ON THE SHORT EDGE
 * ─────────────────────────────────────────────────────────────────────
 *
 * The obvious rule — "cap the longest side" — is wrong here, and a test
 * caught it. Covers are drawn with BoxFit.cover into landscape boxes:
 * the course hero is 350x236pt, which is 1050x708 device pixels on a 3x
 * phone. Covering a landscape box with a PORTRAIT image is bound by the
 * image's WIDTH, which is its short edge.
 *
 * Capping the long edge at 1600 took the 1242x2688 the artwork brief
 * asks for down to 739x1600 — a width of 739 where 1050 was needed, so
 * every portrait cover would have been visibly soft on the hero. The
 * cap therefore lands on the short edge instead, with a second, looser
 * cap on the long edge so a panorama cannot come through enormous just
 * because it happens to be short.
 *
 * ─────────────────────────────────────────────────────────────────────
 *  THIS MUST NEVER FAIL AN UPLOAD
 * ─────────────────────────────────────────────────────────────────────
 *
 * An optimiser that rejects the file is worse than no optimiser: the
 * admin is a person with a deadline and a JPEG, and "could not process
 * image" leaves them stuck with no way round it. Anything sharp cannot
 * read — a PDF, an SVG, a corrupt file, a format this build wasn't
 * compiled with — comes back untouched and gets stored as-is.
 */
/// Short edge. Must clear the 1050 device pixels the course hero needs,
/// with headroom for a phone denser or wider than the 3x/390pt baseline.
const MAX_SHORT_EDGE = 1200;

/// Long edge. Purely a size bound, so an extreme aspect ratio cannot
/// produce a huge file while technically respecting the short-edge cap.
const MAX_LONG_EDGE = 2400;

const QUALITY = 82;

export type ShrunkImage = {
  bytes: Buffer;
  contentType: string;
  /** File extension without the dot, matching [contentType]. */
  ext: string;
  /** True when the image was actually re-encoded. For logging only. */
  changed: boolean;
};

/**
 * Returns the image re-encoded within the caps above, or the original
 * bytes unchanged if it cannot be processed.
 *
 * Output is always JPEG, except for images with an alpha channel, which
 * stay PNG — flattening a transparent logo onto black is the kind of
 * silent damage that gets noticed a week later on a live screen.
 */
export async function shrinkImage(
  input: Buffer,
  fallbackContentType: string,
  fallbackExt: string,
): Promise<ShrunkImage> {
  const unchanged: ShrunkImage = {
    bytes: input,
    contentType: fallbackContentType,
    ext: fallbackExt,
    changed: false,
  };

  try {
    const image = sharp(input, { failOn: "none" });
    const meta = await image.metadata();

    // Not a raster image sharp understands, or one with no dimensions to
    // reason about. Store it exactly as it arrived.
    if (!meta.width || !meta.height) return unchanged;

    // Animation would be destroyed by a still re-encode. Rare for a
    // cover, catastrophic when it happens.
    if ((meta.pages ?? 1) > 1) return unchanged;

    const hasAlpha = meta.hasAlpha === true;

    // Measure the image as it will be SEEN, not as it is stored. EXIF
    // orientations 5-8 are the quarter-turns, and for those the stored
    // width and height are the wrong way round — a portrait photo from
    // a phone camera is commonly stored landscape with a rotate flag.
    // Measuring the stored axes would pick the wrong short edge and
    // scale by the wrong rule.
    //
    // Read from metadata rather than by rendering the rotation and
    // measuring the result: this runs inside a server action, and
    // decoding the whole image twice to learn two numbers is a cost
    // paid on every upload for nothing.
    const swapped = (meta.orientation ?? 1) >= 5;
    const w = swapped ? meta.height : meta.width;
    const h = swapped ? meta.width : meta.height;

    const rotated = image.rotate();

    const shortEdge = Math.min(w, h);
    const longEdge = Math.max(w, h);

    // Never above 1 — a small image is re-encoded but never upscaled.
    // Enlarging a 400px cover to 1200 adds bytes and no detail.
    let scale = Math.min(1, MAX_SHORT_EDGE / shortEdge);
    if (longEdge * scale > MAX_LONG_EDGE) scale = MAX_LONG_EDGE / longEdge;

    const alreadySmallEnough = scale >= 1;

    const pipeline = rotated.resize({
      width: Math.round(w * scale),
      height: Math.round(h * scale),
      fit: "fill",
    });

    const bytes = hasAlpha
      ? await pipeline.png({ compressionLevel: 9 }).toBuffer()
      : await pipeline.jpeg({ quality: QUALITY, mozjpeg: true }).toBuffer();

    // A re-encode that made the file bigger is a re-encode worth
    // throwing away. Happens with images already optimised harder than
    // this, and with small PNGs.
    if (bytes.byteLength >= input.byteLength && alreadySmallEnough) {
      return unchanged;
    }

    return {
      bytes,
      contentType: hasAlpha ? "image/png" : "image/jpeg",
      ext: hasAlpha ? "png" : "jpg",
      changed: true,
    };
  } catch {
    // Deliberately swallowed. See the header: the upload proceeds with
    // the original bytes rather than failing in front of the admin.
    return unchanged;
  }
}
