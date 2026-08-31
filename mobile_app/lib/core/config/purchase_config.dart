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

/// Whether the app presents its long-form content as a course.
///
/// False on iOS, for the other half of the 3.1.3(a) claim. The reader
/// exception covers magazines, newspapers, books, audio, music and
/// video — it does not mention education, and the rejection named the
/// courses specifically. A reviewer decides which of those they are
/// looking at from what the app does, so this is not a relabelling
/// exercise: the completion certificate is withheld too, because an
/// issued credential is the one feature no video service has and the
/// clearest evidence that this is a course rather than a series.
///
/// Netflix has episodes, sequencing, locked items and continue-watching.
/// None of those are education signals and none of them are touched.
/// What changes is the vocabulary around them — lesson, enrolled,
/// curriculum, continue *learning* — and the credential at the end.
///
/// The certificate record itself is untouched server-side. It is still
/// earned, still issued, still verifiable at /verify; an iOS member
/// simply is not shown it. If review accepts the courses as they are,
/// flipping this back restores the feature with no data to migrate.
final bool kEducationFramingEnabled =
    defaultTargetPlatform != TargetPlatform.iOS;

/// Whether the in-app guide is offered.
///
/// Off on iOS, and this one is about eligibility rather than about
/// purchases.
///
/// On 27 August 2026 Apple denied the External Link Account Entitlement,
/// stating that this app "does not qualify as a reader app". A reader app
/// is one whose PRIMARY functionality is one of the listed content types
/// — magazines, newspapers, books, audio, music, video. The guide is an
/// assistant: it is the app's most distinctive feature, it sits above the
/// catalogue on Home, and the App Store promotional text leads with it.
/// It is the clearest reason an evaluator would conclude the primary
/// functionality is something other than a library of audio and video.
///
/// Netflix and Spotify qualify because opening them puts you in a
/// catalogue and nothing else. With this off, the iOS build is the same
/// shape: audio, video series, downloads, and where you were.
///
/// Gating rather than deleting, on one platform only. Android keeps the
/// guide in full — nothing about Android is affected by any of this — and
/// if the entitlement is granted, or the position changes, flipping this
/// back restores the feature with nothing to migrate and no server change.
///
/// [kPurchaseUiEnabled] is deliberately NOT reused for this. The two
/// happen to have the same value today, but they answer different
/// questions: that one is "may this build show a price", this one is "does
/// this build look like a reader app". Conflating them would mean a future
/// change to either silently moving the other.
final bool kGuideEnabled = defaultTargetPlatform != TargetPlatform.iOS;

/// Whether the iOS build shows the single external link to the website for
/// account creation and management.
///
/// True on iOS ONLY. On 3 September 2026 Apple granted the External Link
/// Account Entitlement for com.anuragrishi.knowthyself, reversing the 27
/// August denial documented above under [kGuideEnabled]. That entitlement
/// permits exactly ONE neutral link out to our own website for creating or
/// managing an account — no price, no buy button, no "Subscribe", no
/// promotion. It is the only in-app route by which an iPhone member can
/// reach a checkout, which until now did not exist at all (the in-app
/// checkout is gated off by [kPurchaseUiEnabled]).
///
/// Android and web are unaffected and keep the full in-app purchase flow, so
/// the link is not shown there — it would be a strictly worse path than the
/// one they already have.
///
/// [externalAccountUrl] MUST match SKExternalLinkAccount in Info.plist and
/// the entitlement com.apple.developer.storekit.external-link.account in
/// Runner.entitlements, or App Review's binary-vs-plist check fails the link.
final bool kExternalAccountLinkEnabled =
    defaultTargetPlatform == TargetPlatform.iOS;

/// The external account-management URL surfaced under the entitlement.
///
/// MUST be byte-identical to the '*' value in Info.plist's
/// SKExternalLinkAccount. Apple requires an https absolute URL with NO query
/// parameters and 1000 or fewer ASCII characters; the store page satisfies
/// all three. It is the same host Razorpay has approved, so a buyer who
/// continues to a purchase there does not hit an unverified-website wall.
const String externalAccountUrl = 'https://pay.anuragrishi.com/store';

/// What one item inside a course is called, in the singular.
///
/// "Lesson" is the word that makes a list of videos a curriculum.
/// "Episode" is the same list without the claim.
String get kPartWord => kEducationFramingEnabled ? 'lesson' : 'episode';

/// What a locked item says when there is no way to buy it in-app.
///
/// Deliberately says nothing about price, purchasing, or where to go —
/// naming the website next to locked content reads as a purchase link,
/// which is the thing 3.1.3(a) forbids. People arrive here already
/// knowing where they bought; the app's job is only to let them in.
const String kLockedContentMessage =
    'This is available with active access. If you already have it, sign '
    'in with that account and it will unlock automatically.';
