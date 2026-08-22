/**
 * The details that appear on the public policy pages.
 *
 * ─────────────────────────────────────────────────────────────────────
 *  EVERY VALUE MARKED "CONFIRM" MUST BE CHECKED BEFORE THESE PAGES ARE
 *  SUBMITTED TO RAZORPAY OR LINKED FROM THE APP STORES.
 * ─────────────────────────────────────────────────────────────────────
 *
 * Kept in one file rather than written into four pages, because these
 * are the facts a reviewer cross-checks against the Razorpay account and
 * the store listings. Four copies of an address is four chances for one
 * of them to be stale, and a mismatch is the most common reason a
 * website submission is rejected.
 *
 * The refund terms below are a workable default for an app selling
 * digital audio, courses and seats at live sessions — they are not
 * legal advice, and the business owner should confirm they can stand
 * behind every sentence before anybody relies on them.
 */
export const legal = {
  /** CONFIRM: exactly as registered with Razorpay. A mismatch between
   *  this and the account name is a standard rejection. */
  businessName: "Anurag Rishi",

  /** CONFIRM: the brand customers recognise. Used in prose. */
  tradingName: "Know Thyself",

  /** CONFIRM */
  email: "ar.happinessmovement@gmail.com",

  /** CONFIRM: a number a customer can actually reach on a working day.
   *  Razorpay checks that one is published. */
  phone: "+91 7373738391",

  /** CONFIRM: full postal address, including PIN code. */
  address: "SCO 269 OLD MUGAL CANAL, KARNAL, Canal Colony Karnal, Karnal, HARYANA, 132001",

  /** CONFIRM: the courts named in the Terms. Normally where the
   *  business is registered. */
  jurisdiction: "Delhi, India",

  /** Shown on every page. Update when the wording changes, not on every
   *  deploy — a date that moves for no reason tells a reader nothing. */
  lastUpdated: "6 August 2026",

  /** CONFIRM: hours before a live session in which a refund can still be
   *  requested. Set to 0 to refuse refunds once a seat is booked. */
  sessionRefundHours: 24,

  /** CONFIRM: days after purchase in which an untouched course can be
   *  refunded. Set to 0 to refuse refunds on courses entirely. */
  courseRefundDays: 7,
} as const;

/** Where support requests are told to go, in one phrase. */
export const contactLine = `${legal.email} or ${legal.phone}`;

/**
 * Where a storefront buyer is sent to collect what they just bought.
 *
 * Only the web checkout needs these. Somebody who bought inside the app
 * already has the app; somebody who bought on the website may never have
 * opened it, and telling them to "return to the app" is the fastest way
 * to turn a completed payment into a support email.
 */
export const appLinks = {
  /** Derived from the Flutter applicationId, so this one cannot drift. */
  play:
    "https://play.google.com/store/apps/details?id=com.anuragrishi.knowthyself",

  /** CONFIRM: Apple assigns the numeric id at first approval, and there
   *  is no way to derive it from the bundle id. Until it is filled in,
   *  the checkout page hides the iOS button rather than linking
   *  somewhere wrong — a dead App Store link on a payment confirmation
   *  is worse than no link. Find it in App Store Connect under
   *  General → App Information → Apple ID. */
  appStore: "" as string,
} as const;
