/// admin: staff role, unlimited access to everything.
/// retreat: an active (possibly unlimited) access window was granted.
/// free: never granted a window (self-signup default) or it expired.
enum UserTier { admin, retreat, free }

const _staffRoles = {'admin', 'content_manager', 'support'};

/// The user's role/retreat-access window plus the global "next event"
/// pop-up. Drives whether the home screen shows audio at all and whether
/// the pop-up is displayed.
class AccessState {
  /// profiles.role. Null is treated as a non-staff user.
  final String? role;

  /// When the account was actually granted a window (set by most admin
  /// grant actions, but not all — see [tier]). Only consulted when
  /// [expiresAt] is null, to disambiguate "never granted" from "granted
  /// unlimited access".
  final DateTime? accessStartedAt;

  /// When the user's access lapses. A non-null value always wins (see
  /// [tier]) — active iff in the future, regardless of [accessStartedAt].
  final DateTime? expiresAt;

  /// Pop-up content (admin-editable). Null fields mean "not configured".
  final bool popupEnabled;
  final DateTime? popupStartAt;
  final String? popupTitle;
  final String? popupBody;
  final String? popupImageUrl;

  const AccessState({
    required this.role,
    required this.accessStartedAt,
    required this.expiresAt,
    required this.popupEnabled,
    required this.popupStartAt,
    required this.popupTitle,
    required this.popupBody,
    required this.popupImageUrl,
  });

  UserTier get tier {
    if (role != null && _staffRoles.contains(role)) return UserTier.admin;
    if (expiresAt != null) {
      return expiresAt!.isAfter(DateTime.now())
          ? UserTier.retreat
          : UserTier.free;
    }
    return accessStartedAt != null ? UserTier.retreat : UserTier.free;
  }

  /// True while the user may still see and play content.
  bool get hasAccess => tier != UserTier.free;

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
    role: null,
    accessStartedAt: null,
    expiresAt: null,
    popupEnabled: false,
    popupStartAt: null,
    popupTitle: null,
    popupBody: null,
    popupImageUrl: null,
  );
}
