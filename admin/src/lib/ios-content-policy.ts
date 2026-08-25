/**
 * Whether admin-authored text is safe to put on an iOS screen.
 *
 * ─────────────────────────────────────────────────────────────────────
 *  KEEP IN SYNC WITH
 *  mobile_app/lib/core/config/ios_content_policy.dart
 * ─────────────────────────────────────────────────────────────────────
 *  The two files implement the same rule in two languages because they
 *  cannot share code. THIS file only warns the person typing. The Dart
 *  one enforces, and is the one that actually protects the listing —
 *  this warning can be ignored, does not apply to rows already in the
 *  database, and says nothing about what is inside an uploaded image.
 *
 *  If you change the patterns here, change them there too.
 * ─────────────────────────────────────────────────────────────────────
 *
 * The iOS build ships as a reader app under App Store Guideline
 * 3.1.3(a): no purchase mechanism, and no call to action pointing at
 * one. Pop-up text is free text an admin types, stored in the database
 * and rendered verbatim on both platforms, so it is the one route by
 * which a price or a "Register now" can reach an iOS screen without any
 * code change. The app suppresses such a pop-up on iOS; this tells the
 * author that will happen, at the moment they write it, rather than
 * leaving them to wonder later why iPhone users never saw it.
 */

/** Currency and amount patterns. A bare number is fine — "20 minutes"
 *  and "Day 3" are not prices. A number beside a currency marker is. */
const PRICE =
  /(₹|Rs\.?|INR|\$|USD|EUR|£)\s*\d|\d+\s*(₹|Rs\.?|INR|rupees?|rs)\b|\b\d+\s*\/-/i;

/** Words that make a sentence an instruction to buy, or to sign up for
 *  something that is bought. Deliberately narrow: "join us", "watch now"
 *  and "start today" are invitations to use the app, and a pop-up
 *  wrongly hidden on iOS is a message the audience never receives. */
const COMMERCE =
  /\b(buy|purchase|checkout|check\s?out|subscribe|subscription|pay\s?now|payment|paid|price|pricing|cost|fee|fees|charges?|discount|offer\s+ends|limited\s+seats?|early\s+bird|enrol|enroll|enrolment|enrollment|register|registration|sign\s?up|book\s+(now|your|a)\s*|upgrade|renew)\b/i;

export type IosPolicyResult = {
  /** True when this pop-up will be withheld from iOS. */
  violates: boolean;
  /** Which fields tripped it, for a message that names them. */
  fields: string[];
  /** The matched fragments, so the author can see what to change. */
  matches: string[];
};

function offendingMatch(text: string | null | undefined): string | null {
  if (!text) return null;
  const t = text.trim();
  if (!t) return null;
  return (t.match(PRICE) ?? t.match(COMMERCE))?.[0] ?? null;
}

/**
 * Checks the three free-text fields of a pop-up.
 *
 * Note what is NOT checked: `image_url`. Nothing here can read the
 * words baked into a JPEG, which is why the pop-up form also carries an
 * explicit "hide on iOS" switch — artwork is a judgement only the
 * person who made it can make.
 */
export function checkPopupForIos(input: {
  title?: string | null;
  body?: string | null;
  cta_label?: string | null;
}): IosPolicyResult {
  const checks: [string, string | null | undefined][] = [
    ["title", input.title],
    ["body", input.body],
    ["button label", input.cta_label],
  ];

  const fields: string[] = [];
  const matches: string[] = [];
  for (const [name, value] of checks) {
    const hit = offendingMatch(value);
    if (hit) {
      fields.push(name);
      matches.push(hit);
    }
  }

  return { violates: fields.length > 0, fields, matches };
}
