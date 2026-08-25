import 'package:flutter/material.dart';

/// Whether to ask Supabase Storage for a resized copy of an image
/// instead of the full-size original.
///
/// Supabase image transformations are a Pro-plan feature and can be
/// switched off at the project level. If they are unavailable the
/// render URLs return an error, and [RemoteImage] silently falls back
/// to the original URL for that image — so this being wrong costs a
/// wasted request per image, never a broken screen.
///
/// Set to false to stop even trying, once you know the answer.
const bool kSupabaseImageTransformsEnabled = true;

/// A network image that is fetched and decoded at the size it will
/// actually be drawn.
///
/// ─────────────────────────────────────────────────────────────────────
///  THIS IS A PERFORMANCE FIX. DO NOT REPLACE IT WITH A BARE
///  Image.network BECAUSE THAT LOOKS SIMPLER.
/// ─────────────────────────────────────────────────────────────────────
///
/// Every cover in this app was previously drawn with a plain
/// `Image.network`, which decodes at the source file's full resolution
/// no matter how small the box is. The covers are authored at phone
/// wallpaper size — 1242x2688 was the brief — so a 52x52 thumbnail on
/// the home screen was decoding a 1242x2688 bitmap and holding it in
/// memory: 1242 x 2688 x 4 bytes, about 13 MB, for a tile the size of a
/// fingernail.
///
/// Flutter's ImageCache holds 100 MB by default, so roughly eight of
/// those fill it. Past that it evicts, and an evicted image has to be
/// decoded again the next time it is painted. That was the reported
/// symptom: scrolling slowly back up a screen stuttered where scrolling
/// down had not, because on the way up every cover was being decoded a
/// second time.
///
/// This widget closes both ends of that:
///
///   1. DECODE. cacheWidth/cacheHeight decode straight to the display
///      size — about 200 KB rather than 13 MB. This works for every
///      image, wherever it is hosted.
///
///   2. DOWNLOAD. For images in Supabase Storage, the URL is rewritten
///      to ask the server for a copy already scaled to that size, so
///      the 4 MB never crosses the network at all. Images hosted
///      anywhere else — Bunny, YouTube thumbnails — are left alone.
///
/// Only ONE of cacheWidth/cacheHeight is ever passed. Flutter's
/// ResizeImage scales to exactly the dimensions given, so passing both
/// would squash any image whose aspect ratio differs from its box.
/// Passing one lets the other scale in proportion, and [fit] crops the
/// overflow as before.
class RemoteImage extends StatefulWidget {
  /// Null or empty renders [fallback] without touching the network.
  final String? url;

  /// Shown when there is no url, and when the fetch or decode fails.
  final Widget fallback;

  /// Also shown while the image is still arriving. Off by default,
  /// because on a fast connection it flashes; on at the call sites that
  /// were already doing it via loadingBuilder.
  final bool fallbackWhileLoading;

  final BoxFit fit;

  const RemoteImage({
    super.key,
    required this.url,
    required this.fallback,
    this.fallbackWhileLoading = false,
    this.fit = BoxFit.cover,
  });

  @override
  State<RemoteImage> createState() => _RemoteImageState();
}

class _RemoteImageState extends State<RemoteImage> {
  /// Set once this particular image has failed to load from a resized
  /// URL, after which it is fetched from the original.
  ///
  /// Per-image rather than global on purpose. A global switch would be
  /// tripped by a single genuinely missing file — the image 404s, the
  /// switch flips, and every other image in the app quietly loses its
  /// optimisation for the rest of the session, with nothing to show
  /// that it happened.
  bool _useOriginal = false;

  @override
  void didUpdateWidget(RemoteImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A recycled tile showing a different image starts fresh: the
    // previous url failing says nothing about this one.
    if (oldWidget.url != widget.url) _useOriginal = false;
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.url;
    if (source == null || source.isEmpty) return widget.fallback;

    // LayoutBuilder rather than a hardcoded size: the same widget is
    // used in a 40px mini-player tile and a full-bleed course hero, and
    // a size passed by hand is a size that goes stale the first time
    // somebody changes the layout around it.
    return LayoutBuilder(
      builder: (context, constraints) {
        final ratio = MediaQuery.devicePixelRatioOf(context);
        final width = constraints.hasBoundedWidth ? constraints.maxWidth : null;
        final height =
            constraints.hasBoundedHeight ? constraints.maxHeight : null;

        // Size by the longer edge of the box. Under BoxFit.cover the
        // longer edge is the one that can demand the most pixels, so
        // this is the choice that cannot come out soft.
        int? cacheWidth;
        int? cacheHeight;
        if (width != null && (height == null || width >= height)) {
          cacheWidth = (width * ratio).round();
        } else if (height != null) {
          cacheHeight = (height * ratio).round();
        }

        final resized = _useOriginal
            ? null
            : _supabaseRenderUrl(source, cacheWidth, cacheHeight);
        final target = resized ?? source;

        return Image.network(
          target,
          fit: widget.fit,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
          errorBuilder: (context, error, stack) {
            // A resized URL that failed is worth one retry against the
            // original — the project may not have transformations
            // enabled. setState is deferred because errorBuilder runs
            // during the build it would be interrupting.
            if (resized != null && !_useOriginal) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _useOriginal = true);
              });
            }
            return widget.fallback;
          },
          loadingBuilder: widget.fallbackWhileLoading
              ? (context, child, progress) =>
                  progress == null ? child : widget.fallback
              : null,
        );
      },
    );
  }
}

/// Rewrites a Supabase Storage public URL into its resizing endpoint,
/// or returns null for a URL this does not apply to.
///
///   .../storage/v1/object/public/covers/x.jpg
///   .../storage/v1/render/image/public/covers/x.jpg?width=468&quality=75
///
/// Returns null — meaning "use the original" — for anything not served
/// from Supabase Storage, so Bunny artwork and YouTube thumbnails pass
/// through untouched.
String? _supabaseRenderUrl(String raw, int? width, int? height) {
  if (!kSupabaseImageTransformsEnabled) return null;
  if (width == null && height == null) return null;

  const objectPath = '/storage/v1/object/public/';
  const renderPath = '/storage/v1/render/image/public/';
  if (!raw.contains(objectPath)) return null;

  final uri = Uri.tryParse(raw);
  if (uri == null) return null;

  // Existing query parameters are preserved, not replaced. Pop-up
  // artwork carries a `?v=` cache-buster appended at upload — dropping
  // it would leave every device showing the previous image after the
  // admin replaces one.
  final params = Map<String, String>.from(uri.queryParameters);

  // Supabase rejects dimensions outside its own bounds, and a rejected
  // request is a wasted round trip before the fallback. Clamped here so
  // that never happens.
  if (width != null) params['width'] = '${width.clamp(1, 2500)}';
  if (height != null) params['height'] = '${height.clamp(1, 2500)}';
  params['quality'] = '75';

  return uri
      .replace(
        path: uri.path.replaceFirst(objectPath, renderPath),
        queryParameters: params,
      )
      .toString();
}
