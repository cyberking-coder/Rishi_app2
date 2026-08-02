/// What a certificate says. Course title and recipient name are snapshots
/// taken when it was issued, not live joins — a course renamed afterwards
/// must not rewrite credentials already awarded.
class Certificate {
  final String id;
  final String certificateNumber;
  final String courseTitle;
  final String? recipientName;
  final DateTime issuedAt;
  final DateTime? revokedAt;

  /// The admin's own artwork for this course, if they uploaded any, and
  /// where the recipient's name goes on it. Read from the course rather
  /// than snapshotted onto the certificate: the design is presentation,
  /// so re-uploading better artwork should improve every certificate
  /// already issued — unlike the course TITLE, which is a claim about
  /// what was earned and must never change retroactively.
  final CertificateLayout? layout;

  const Certificate({
    required this.id,
    required this.certificateNumber,
    required this.courseTitle,
    required this.issuedAt,
    this.recipientName,
    this.revokedAt,
    this.layout,
  });

  Certificate withLayout(CertificateLayout? value) => Certificate(
        id: id,
        certificateNumber: certificateNumber,
        courseTitle: courseTitle,
        recipientName: recipientName,
        issuedAt: issuedAt,
        revokedAt: revokedAt,
        layout: value,
      );

  bool get isValid => revokedAt == null;

  factory Certificate.fromMap(Map<String, dynamic> map) => Certificate(
        id: map['id'] as String? ?? '',
        certificateNumber: map['certificate_number'] as String? ?? '',
        courseTitle: map['course_title'] as String? ?? 'Course',
        recipientName: map['recipient_name'] as String?,
        issuedAt:
            DateTime.tryParse(map['issued_at'] as String? ?? '')?.toLocal() ??
                DateTime.now(),
        revokedAt: map['revoked_at'] == null
            ? null
            : DateTime.tryParse(map['revoked_at'] as String)?.toLocal(),
      );
}

/// Admin-uploaded certificate artwork and where the name is printed on
/// it. All positions are PERCENTAGES of the image, never pixels, so one
/// template lands correctly on any screen and at any export resolution.
class CertificateLayout {
  final String templateUrl;

  /// 0 = top edge, 100 = bottom edge. The name's vertical centre.
  final double topPercent;

  /// 0 = left edge, 100 = right edge. The name's horizontal centre.
  final double leftPercent;

  /// Font size as a percentage of the image's width.
  final double sizePercent;
  final int colorValue;

  const CertificateLayout({
    required this.templateUrl,
    required this.topPercent,
    required this.leftPercent,
    required this.sizePercent,
    required this.colorValue,
  });

  static CertificateLayout? fromMap(Map<String, dynamic>? map) {
    final url = map?['certificate_template_url'] as String?;
    if (map == null || url == null || url.isEmpty) return null;

    return CertificateLayout(
      templateUrl: url,
      topPercent: (map['certificate_name_top'] as num?)?.toDouble() ?? 52,
      leftPercent: (map['certificate_name_left'] as num?)?.toDouble() ?? 50,
      sizePercent: (map['certificate_name_size'] as num?)?.toDouble() ?? 7,
      colorValue: _parseHex(map['certificate_name_color'] as String?),
    );
  }

  /// '#1A1A1A' -> 0xFF1A1A1A. Falls back to near-black rather than
  /// throwing: a malformed colour should print a readable name, not
  /// break the certificate.
  static int _parseHex(String? hex) {
    if (hex == null) return 0xFF1A1A1A;
    final cleaned = hex.replaceAll('#', '').trim();
    if (cleaned.length != 6) return 0xFF1A1A1A;
    return int.tryParse('FF$cleaned', radix: 16) ?? 0xFF1A1A1A;
  }
}

/// Progress toward a certificate, straight from course_completion_state.
class CourseCompletion {
  final int lessonCount;
  final int lessonsCompleted;
  final bool complete;

  const CourseCompletion({
    this.lessonCount = 0,
    this.lessonsCompleted = 0,
    this.complete = false,
  });

  factory CourseCompletion.fromMap(Map<String, dynamic> map) =>
      CourseCompletion(
        lessonCount: (map['lesson_count'] as num?)?.toInt() ?? 0,
        lessonsCompleted: (map['lessons_completed'] as num?)?.toInt() ?? 0,
        complete: map['complete'] as bool? ?? false,
      );

  /// Everything that has to be done, and how much of it is. Lessons are
  /// the whole of it — course_completion_state() still returns quiz
  /// counts for shape compatibility, but they are always zero since
  /// quizzes were removed from the product, so they aren't read here.
  int get totalSteps => lessonCount;
  int get completedSteps => lessonsCompleted;

  double get fraction => totalSteps == 0 ? 0 : completedSteps / totalSteps;
}
