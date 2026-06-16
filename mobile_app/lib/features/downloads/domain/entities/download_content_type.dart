/// Whether a download is a video or an audio asset. Drives which license
/// edge function is called and the MIME type the playback proxy reports.
enum DownloadContentType {
  video,
  audio;

  String get mimeType => switch (this) {
        DownloadContentType.video => 'video/mp4',
        DownloadContentType.audio => 'audio/mpeg',
      };

  String get wireName => name;

  static DownloadContentType fromWire(String value) =>
      DownloadContentType.values.firstWhere((e) => e.name == value);
}
