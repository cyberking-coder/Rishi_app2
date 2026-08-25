import 'package:flutter/material.dart';

/// A network image that is decoded at the size it will actually be drawn.
///
/// ─────────────────────────────────────────────────────────────────────
///  THIS IS A PERFORMANCE FIX. THE cacheWidth/cacheHeight ARGUMENT IS
///  THE ENTIRE POINT OF THIS WIDGET — DO NOT DROP BACK TO A BARE
///  Image.network BECAUSE IT LOOKS SIMPLER.
/// ─────────────────────────────────────────────────────────────────────
///
/// Every cover in this app was previously drawn with a plain
/// `Image.network`, which decodes at the source file's full resolution
/// no matter how small the box is. The covers are authored at phone
/// wallpaper size — 1242×2688 was the brief — so a 52×52 thumbnail on
/// the home screen was decoding a 1242×2688 bitmap and holding it in
/// memory: 1242 × 2688 × 4 bytes ≈ 13 MB, for a tile the size of a
/// fingernail.
///
/// Flutter's ImageCache holds 100 MB by default, so roughly eight of
/// those fill it. Past that it evicts, and an evicted image has to be
/// decoded again the next time it is painted. That is exactly the
/// reported symptom — scrolling slowly back up the home screen stutters
/// where it did not on the way down, because on the way up every cover
/// is being decoded a second time.
///
/// Decoding to the display size instead takes that 13 MB to roughly
/// 200 KB, which both removes the per-decode cost and stops the cache
/// thrashing that caused the repeat decodes.
///
/// Only ONE of cacheWidth/cacheHeight is ever passed. Flutter's
/// ResizeImage scales to exactly the dimensions given, so passing both
/// would squash any image whose aspect ratio differs from its box.
/// Passing one lets the other scale in proportion, and [fit] crops the
/// overflow as before.
class RemoteImage extends StatelessWidget {
  /// Null or empty renders [fallback] without touching the network.
  final String? url;

  /// Shown when there is no url, and when the fetch or decode fails.
  final Widget fallback;

  /// Also shown while the image is still arriving. Off by default,
  /// because on a fast connection it flashes; on by default at call
  /// sites that were already doing it via loadingBuilder.
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
  Widget build(BuildContext context) {
    final source = url;
    if (source == null || source.isEmpty) return fallback;

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

        return Image.network(
          source,
          fit: fit,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
          errorBuilder: (_, __, ___) => fallback,
          loadingBuilder: fallbackWhileLoading
              ? (context, child, progress) =>
                  progress == null ? child : fallback
              : null,
        );
      },
    );
  }
}
