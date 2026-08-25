/// Whether admin-authored text is safe to put on an iOS screen.
///
/// ─────────────────────────────────────────────────────────────────────
///  KEEP IN SYNC WITH admin/src/lib/ios-content-policy.ts
/// ─────────────────────────────────────────────────────────────────────
///  The two files implement the same rule in two languages because they
///  cannot share code: one runs in Dart on a phone, the other in
///  TypeScript on a server. The admin version exists to WARN an author
///  at the moment they type; this one exists to ENFORCE, because the
///  admin warning can be dismissed, predates rows already in the
///  database, and is not the last word on what reaches a reviewer.
///
///  If you change the patterns here, change them there too.
/// ─────────────────────────────────────────────────────────────────────
///
/// WHY THIS EXISTS
///
/// The iOS build ships as a reader app under App Store Guideline
/// 3.1.3(a), which requires that it contain no purchase mechanism and
/// no call to action pointing at one. [kPurchaseUiEnabled] holds every
/// price and button the app itself draws.
///
/// Pop-ups are the hole it cannot reach. Their title, body and button
/// label are free text an admin types into the dashboard, stored in the
/// database and rendered verbatim. An admin writing "Register ₹499" or
/// "Join the live workshop — book now" puts exactly the call to action
/// 3.1.3(a) forbids onto an iOS screen, and no compile-time flag can
/// see inside a string that arrives at runtime.
///
/// So the string is inspected instead. A pop-up whose text trips this
/// is not shown on iOS at all.
///
/// WHY SUPPRESS RATHER THAN REDACT
///
/// Editing the text would be worse. "Register ₹499 for the workshop"
/// with the price stripped still reads as a call to register for a paid
/// event, and a half-scrubbed sentence looks like a bug to the member
/// and like evasion to a reviewer. Showing nothing on iOS is honest,
/// and Android is unaffected — it still gets the pop-up in full.
library;

/// Currency and amount patterns. A number alone is fine: "20 minutes"
/// and "Day 3" are not prices. A number next to a currency marker is.
final RegExp _price = RegExp(
  r'(₹|Rs\.?|INR|\$|USD|EUR|£)\s*\d'
  r'|\d+\s*(₹|Rs\.?|INR|rupees?|rs)\b'
  r'|\b\d+\s*/-',
  caseSensitive: false,
);

/// Words that make a sentence an instruction to buy or to sign up for
/// something that is bought.
///
/// Deliberately narrow. "Join us", "watch now" and "start today" are
/// invitations to use the app and stay; the list below is limited to
/// the ones that read as commerce. Over-blocking has a cost too — a
/// pop-up wrongly hidden on iOS is a message the audience never gets,
/// and nothing on screen explains why.
final RegExp _commerce = RegExp(
  r'\b('
  r'buy|purchase|checkout|check\s?out'
  r'|subscribe|subscription'
  r'|pay\s?now|payment|paid'
  r'|price|pricing|cost|fee|fees|charges?'
  r'|discount|offer\s+ends|limited\s+seats?|early\s+bird'
  r'|enrol|enroll|enrolment|enrollment'
  r'|register|registration|sign\s?up|book\s+(now|your|a)\s*'
  r'|upgrade|renew'
  r')\b',
  caseSensitive: false,
);

/// True when [text] must not be shown on iOS.
bool violatesIosContentPolicy(String? text) {
  if (text == null) return false;
  final t = text.trim();
  if (t.isEmpty) return false;
  return _price.hasMatch(t) || _commerce.hasMatch(t);
}

/// True when any of [texts] must not be shown on iOS.
bool anyViolatesIosContentPolicy(Iterable<String?> texts) =>
    texts.any(violatesIosContentPolicy);
