/// A scheduled live meeting — Zoom today, though nothing here assumes it.
///
/// Sits alongside the YouTube list rather than in Courses because it is
/// the same kind of thing to the person using the app: something to
/// watch, free, that opens outside the app.
class LiveSession {
  final String id;
  final String title;
  final String? description;
  final String joinUrl;
  final String? thumbnailUrl;
  final DateTime startsAt;
  final int durationMinutes;
  final String status;

  /// Registration fee in **paise**. Null or zero means free to join,
  /// which is every session that existed before this.
  final int? priceAmount;

  final String currency;

  /// Null = unlimited.
  final int seatLimit;

  const LiveSession({
    required this.id,
    required this.title,
    required this.joinUrl,
    required this.startsAt,
    required this.durationMinutes,
    required this.status,
    this.description,
    this.thumbnailUrl,
    this.priceAmount,
    this.currency = 'INR',
    this.seatLimit = 0,
  });

  bool get isCancelled => status == 'cancelled';

  /// Whether a seat has to be paid for.
  ///
  /// A paid session's [joinUrl] is always empty — the database blanks it
  /// on the way in and keeps the real link in a table members cannot
  /// read. The link is fetched separately, once a registration exists.
  bool get isPaid => (priceAmount ?? 0) > 0;

  /// The fee as it should read on a button.
  String get priceLabel {
    final rupees = (priceAmount ?? 0) / 100;
    final symbol = currency == 'INR' ? '₹' : '$currency ';
    return rupees % 1 == 0
        ? '$symbol${rupees.toStringAsFixed(0)}'
        : '$symbol${rupees.toStringAsFixed(2)}';
  }

  DateTime get endsAt => startsAt.add(Duration(minutes: durationMinutes));

  /// True from ten minutes before the start until the scheduled end.
  ///
  /// The early window is deliberate: people join a call before it starts,
  /// and a button that stays disabled until the exact minute is a button
  /// that fails the person who was early.
  bool get isLiveNow {
    final now = DateTime.now();
    return !isCancelled &&
        now.isAfter(startsAt.subtract(const Duration(minutes: 10))) &&
        now.isBefore(endsAt);
  }

  bool get isOver => DateTime.now().isAfter(endsAt);

  factory LiveSession.fromMap(Map<String, dynamic> map) => LiveSession(
        id: map['id'] as String? ?? '',
        title: map['title'] as String? ?? 'Live session',
        description: map['description'] as String?,
        joinUrl: map['join_url'] as String? ?? '',
        thumbnailUrl: map['thumbnail_url'] as String?,
        // Stored UTC; shown in the reader's own zone, which is the only
        // zone a start time means anything in.
        startsAt:
            DateTime.parse(map['starts_at'] as String).toLocal(),
        durationMinutes: (map['duration_minutes'] as num?)?.toInt() ?? 60,
        status: map['status'] as String? ?? 'scheduled',
        priceAmount: (map['price_amount'] as num?)?.toInt(),
        currency: map['currency'] as String? ?? 'INR',
        seatLimit: (map['seat_limit'] as num?)?.toInt() ?? 0,
      );
}
