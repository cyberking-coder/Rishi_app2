/// The user's retreat-access window plus the global "next event" pop-up.
/// Drives whether the home screen shows audio at all and whether the
/// pop-up is displayed.
class AccessState {
  /// When the user's access lapses. Null == no expiry (staff/admin).
  final DateTime? expiresAt;

  /// Pop-up content (admin-editable). Null fields mean "not configured".
  final bool popupEnabled;
  final DateTime? popupStartAt;
  final String? popupTitle;
  final String? popupBody;
  final String? popupImageUrl;

  const AccessState({
    required this.expiresAt,
    required this.popupEnabled,
    required this.popupStartAt,
    required this.popupTitle,
    required this.popupBody,
    required this.popupImageUrl,
  });

  /// True while the user may still see and play content.
  bool get hasAccess => expiresAt == null || expiresAt!.isAfter(DateTime.now());

  /// True once access has lapsed — home hides audio, downloads are purged.
  bool get isExpired => !hasAccess;

  /// Whole days left in the access window (0 once expired). Null == no limit.
  int? get daysLeft {
    if (expiresAt == null) return null;
    final diff = expiresAt!.difference(DateTime.now());
    return diff.isNegative ? 0 : diff.inDays;
  }

  /// Whether the next-event pop-up should be shown right now.
  bool get shouldShowPopup {
    if (!popupEnabled) return false;
    if (popupStartAt != null && popupStartAt!.isAfter(DateTime.now())) {
      return false;
    }
    return (popupTitle != null && popupTitle!.isNotEmpty) ||
        (popupBody != null && popupBody!.isNotEmpty);
  }

  static const empty = AccessState(
    expiresAt: null,
    popupEnabled: false,
    popupStartAt: null,
    popupTitle: null,
    popupBody: null,
    popupImageUrl: null,
  );
}
