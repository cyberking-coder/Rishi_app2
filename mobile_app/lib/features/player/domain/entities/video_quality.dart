class VideoQuality {
  final String label; // e.g. "1080p", "720p", "auto"
  final int? bitrate;
  final String url; // signed Cloudflare R2 URL, short TTL

  const VideoQuality({
    required this.label,
    required this.url,
    this.bitrate,
  });
}
