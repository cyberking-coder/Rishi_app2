/// One selectable stream for a video: the adaptive master playlist, or a
/// single fixed rendition.
class PlaybackQuality {
  /// 'Auto', or a height such as '720p'.
  final String label;
  final String url;

  const PlaybackQuality({required this.label, required this.url});
}

/// Everything the player was licensed to play.
///
/// The first option is what plays by default — the adaptive stream when
/// there is one, since letting the player pick per segment beats any
/// fixed guess about the connection. The rest exist so a viewer can
/// override that, which adaptive streaming on its own gives them no way
/// to do.
class PlaybackSources {
  final List<PlaybackQuality> options;

  const PlaybackSources({required this.options});

  PlaybackQuality get preferred => options.first;

  /// A single option is just "the video" — offering a menu to pick it
  /// would be noise.
  bool get isSelectable => options.length > 1;
}
