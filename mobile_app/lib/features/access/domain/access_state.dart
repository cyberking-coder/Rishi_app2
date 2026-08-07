import 'entities/app_popup.dart';

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

  /// Every enabled pop-up, in the order an admin arranged them. Which one
  /// (if any) belongs on screen today is [todaysPopup]'s job — the list
  /// is carried whole so the decision is made in one place rather than
  /// half in a query and half on screen.
  final List<AppPopup> popups;

  const AccessState({
    required this.role,
    required this.accessStartedAt,
    required this.expiresAt,
    this.popups = const [],
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

  /// True for anyone outside a retreat window — including someone who
  /// never had one. Use this to gate premium content, never to destroy
  /// anything: it is true for every ordinary self-signup account.
  bool get isExpired => !hasAccess;

  /// True only for an account that *had* a window and has now run past
  /// the end of it.
  ///
  /// [isExpired] cannot be used for this. It is also true for a user who
  /// was never granted a window at all, which is nearly everybody, and
  /// wiring the download purge to it deleted the downloads of every free
  /// user the moment they returned to the home screen.
  ///
  /// A null [expiresAt] is never lapsed: it means either no window was
  /// ever granted, or one was granted with no end date.
  bool get hasLapsed =>
      expiresAt != null && !expiresAt!.isAfter(DateTime.now());

  /// Whole days left in the access window (0 once expired). Null == no limit.
  int? get daysLeft {
    if (expiresAt == null) return null;
    final diff = expiresAt!.difference(DateTime.now());
    return diff.isNegative ? 0 : diff.inDays;
  }

  /// The pop-up due on screen right now, or null.
  ///
  /// First match wins, by the admin's ordering. Two pop-ups both set to
  /// Monday would otherwise alternate at random between launches, which
  /// looks like a bug from the outside and is impossible to report.
  AppPopup? get todaysPopup {
    for (final popup in popups) {
      if (popup.isDueNow()) return popup;
    }
    return null;
  }

  /// Whether a pop-up should be shown right now.
  bool get shouldShowPopup => todaysPopup != null;

  static const empty = AccessState(
    role: null,
    accessStartedAt: null,
    expiresAt: null,
  );
}
