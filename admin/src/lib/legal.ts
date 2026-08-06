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
  phone: "+91 00000 00000",

  /** CONFIRM: full postal address, including PIN code. */
  address: "REPLACE WITH REGISTERED BUSINESS ADDRESS, City, State, PIN",

  /** CONFIRM: the courts named in the Terms. Normally where the
   *  business is registered. */
  jurisdiction: "Maharashtra, India",

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
