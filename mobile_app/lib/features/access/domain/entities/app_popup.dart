/// One scheduled pop-up.
///
/// A row rather than a set of columns on a config singleton, because the
/// thing being described is a list: a Monday message and a Wednesday
/// message are two objects, not two halves of one.
class AppPopup {
  final String id;
  final String? title;
  final String? body;
  final String? imageUrl;

  /// ISO-8601 weekday — 1 is Monday, 7 is Sunday. Null means every day.
  final int? weekday;

  /// Nothing shows before this, whatever the weekday.
  final DateTime? startsAt;

  final int sortOrder;

  /// Where the button goes — an in-app route such as '/watch'. Null means
  /// the pop-up has no button beyond Close.
  ///
  /// A route, not a URL. The pop-up advertises; the paying happens on the
  /// screen that owns the thing being sold, next to it. Letting an admin
  /// type an arbitrary link here would turn the pop-up into a way to send
  /// members anywhere at all.
  final String? ctaRoute;

  /// Wording on the button. Null falls back to "Register Now".
  final String? ctaLabel;

  const AppPopup({
    required this.id,
    this.title,
    this.body,
    this.imageUrl,
    this.weekday,
    this.startsAt,
    this.sortOrder = 0,
    this.ctaRoute,
    this.ctaLabel,
  });

  factory AppPopup.fromMap(Map<String, dynamic> map) => AppPopup(
        id: map['id'] as String? ?? '',
        title: map['title'] as String?,
        body: map['body'] as String?,
        imageUrl: map['image_url'] as String?,
        weekday: (map['weekday'] as num?)?.toInt(),
        startsAt: map['starts_at'] == null
            ? null
            : DateTime.tryParse(map['starts_at'] as String)?.toLocal(),
        sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
        ctaRoute: map['cta_route'] as String?,
        ctaLabel: map['cta_label'] as String?,
      );

  /// Whether the pop-up has somewhere to send people.
  bool get hasCta => ctaRoute != null && ctaRoute!.isNotEmpty;

  String get ctaText => (ctaLabel?.trim().isNotEmpty ?? false)
      ? ctaLabel!.trim()
      : 'Register Now';

  /// A pop-up with neither a title nor a body has nothing to say, and
  /// showing an empty card would read as a failed image load.
  bool get hasContent =>
      (title?.trim().isNotEmpty ?? false) || (body?.trim().isNotEmpty ?? false);

  /// Whether this one belongs on screen right now.
  ///
  /// The weekday is read in IST, not in the device's zone. The day is
  /// chosen by an admin in India who means *their* Monday; a user whose
  /// phone is on London time would otherwise see the Monday message on
  /// Sunday evening. Every other scheduled thing in this project — live
  /// sessions, the daily audio, the n8n crons — is pinned the same way.
  bool isDueNow() {
    if (!hasContent) return false;
    if (startsAt != null && startsAt!.isAfter(DateTime.now())) return false;
    if (weekday == null) return true;
    return weekday == istNow().weekday;
  }

  /// The date this pop-up is being shown on, in IST — the key the
  /// once-a-day guard remembers it by.
  String get todayKey {
    final now = istNow();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }
}

/// IST is a fixed +05:30 with no daylight saving, so the offset can be
/// added directly and no timezone database is needed.
///
/// Returned as a DateTime whose *fields* read as IST — only .weekday,
/// .year, .month and .day are meaningful on it. Do not compare it to
/// DateTime.now().
DateTime istNow() =>
    DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
