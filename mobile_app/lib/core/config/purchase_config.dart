import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;

/// Whether the app may show prices and routes to payment.
///
/// False on iOS. App Review rejected 2.1.1 under Guideline 3.1.1 for
/// sending people to the web checkout, so the iOS build ships as a
/// reader app under 3.1.3(a): it plays content bought elsewhere and
/// contains no purchase mechanism at all. That exception is only
/// available to an app with *no* purchase mechanism, so this has to
/// cover every price string too, not just the buttons — a locked course
/// still showing "₹499" is a purchase mechanism as far as review is
/// concerned.
///
/// Android and the web checkout are untouched: they keep Razorpay and
/// full margin. This flag exists so that stays a one-line difference
/// rather than a fork.
///
/// If review still rejects the reader framing — most likely over the
/// courses, which are lessons and certificates rather than the audio
/// and video 3.1.3(a) enumerates — then StoreKit goes behind this same
/// flag rather than reinstating the external links. Shipping a clean
/// build and restoring the links afterwards would be Guideline 2.3.1
/// (hidden features), which risks the developer account rather than
/// just the release.
///
/// `defaultTargetPlatform` rather than `Platform.isIOS` so this file
/// carries no `dart:io` import, and so a test can override it.
final bool kPurchaseUiEnabled = defaultTargetPlatform != TargetPlatform.iOS;

/// What a locked item says when there is no way to buy it in-app.
///
/// Deliberately says nothing about price, purchasing, or where to go —
/// naming the website next to locked content reads as a purchase link,
/// which is the thing 3.1.3(a) forbids. People arrive here already
/// knowing where they bought; the app's job is only to let them in.
const String kLockedContentMessage =
    'This is available with active access. If you already have it, sign '
    'in with that account and it will unlock automatically.';
