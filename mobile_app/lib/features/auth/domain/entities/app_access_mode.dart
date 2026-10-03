/// The single, app-wide access state. Every screen and the router read this
/// instead of each deciding "am I logged in?" their own way (splash,
/// router and profile used to disagree, which is what produced the
/// reinstall "logged in but broken" bug).
///
/// The guiding principle:
///   • a Supabase session is IDENTITY (authentication), and
///   • the offline token is only LOCAL PERMISSION to use already-verified
///     downloaded content for a limited time.
/// They are never the same thing.
enum AppAccessMode {
  /// Still working out the mode at startup. The splash holds here.
  resolving,

  /// A live Supabase session exists (or was just refreshed). Full app.
  authenticatedOnline,

  /// No live session, but this device was verified before and is within its
  /// offline grace period. Only downloaded/cached content is allowed.
  authenticatedOffline,

  /// No identity at all — go to login.
  signedOut,
}

/// Result of attempting a session refresh, for [decideAccessMode].
enum RefreshOutcome {
  /// No refresh was attempted (offline, or not needed).
  notAttempted,

  /// Refresh returned a valid session.
  success,

  /// The server rejected the refresh (invalid/expired refresh token) — a
  /// definitive sign-out, distinct from a network failure.
  invalid,

  /// The refresh could not complete due to connectivity, not credentials.
  networkError,
}

/// Pure decision for the 3-state model — the flowchart, with no IO, so the
/// whole truth table is unit-testable.
///
/// The caller supplies the facts it has gathered; when the online branch
/// needs a refresh it performs it and passes the [refreshOutcome]. With
/// [RefreshOutcome.notAttempted] on that branch the answer is [resolving],
/// meaning "caller must attempt the refresh, then decide again".
AppAccessMode decideAccessMode({
  required bool hasSession,
  required bool hasOfflineIdentity,
  required bool offlineStillValid,
  required bool hasNetwork,
  RefreshOutcome refreshOutcome = RefreshOutcome.notAttempted,
}) {
  // Identity present → online. The backend stays authoritative for
  // subscription / entitlement / device-lock / license on each call.
  if (hasSession) return AppAccessMode.authenticatedOnline;

  // No identity ever established on this install (e.g. a fresh reinstall:
  // the offline token lives in secure storage, which Android backup does
  // not restore) → sign in.
  if (!hasOfflineIdentity) return AppAccessMode.signedOut;

  // Offline identity exists. With no network we cannot verify, so fall back
  // to the local grace period: play downloads until it expires.
  if (!hasNetwork) {
    return offlineStillValid
        ? AppAccessMode.authenticatedOffline
        : AppAccessMode.signedOut;
  }

  // Online but no live session: a refresh decides it.
  switch (refreshOutcome) {
    case RefreshOutcome.success:
      return AppAccessMode.authenticatedOnline;
    case RefreshOutcome.invalid:
      return AppAccessMode.signedOut;
    case RefreshOutcome.networkError:
      return offlineStillValid
          ? AppAccessMode.authenticatedOffline
          : AppAccessMode.signedOut;
    case RefreshOutcome.notAttempted:
      return AppAccessMode.resolving;
  }
}
