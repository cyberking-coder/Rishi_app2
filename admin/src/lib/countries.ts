/**
 * Countries and their dial codes, for the checkout billing form.
 *
 * India first and default — it is where the business is registered,
 * where Razorpay settles, and where the overwhelming majority of buyers
 * are. The rest follow alphabetically.
 *
 * The list is not the full ISO-3166 set. It is India plus the places
 * this audience actually lives: the Gulf, the anglophone diaspora, and
 * the larger European markets. A shorter list is easier to scroll on a
 * phone than 250 entries, and a name missing from it is a support email
 * rather than a lost sale — whereas a 250-item native select on a
 * mid-range Android is a genuinely unpleasant thing to operate.
 *
 * If someone reports their country is missing, add it here. That is the
 * whole maintenance story.
 */
export type Country = {
  /** ISO-3166 alpha-2. Stored, not displayed. */
  code: string;
  name: string;
  /** E.164 calling code, with the plus. */
  dial: string;
};

export const COUNTRIES: Country[] = [
  { code: "IN", name: "India", dial: "+91" },

  { code: "AU", name: "Australia", dial: "+61" },
  { code: "AT", name: "Austria", dial: "+43" },
  { code: "BH", name: "Bahrain", dial: "+973" },
  { code: "BD", name: "Bangladesh", dial: "+880" },
  { code: "BE", name: "Belgium", dial: "+32" },
  { code: "BR", name: "Brazil", dial: "+55" },
  { code: "CA", name: "Canada", dial: "+1" },
  { code: "CN", name: "China", dial: "+86" },
  { code: "DK", name: "Denmark", dial: "+45" },
  { code: "EG", name: "Egypt", dial: "+20" },
  { code: "FI", name: "Finland", dial: "+358" },
  { code: "FR", name: "France", dial: "+33" },
  { code: "DE", name: "Germany", dial: "+49" },
  { code: "HK", name: "Hong Kong", dial: "+852" },
  { code: "ID", name: "Indonesia", dial: "+62" },
  { code: "IE", name: "Ireland", dial: "+353" },
  { code: "IL", name: "Israel", dial: "+972" },
  { code: "IT", name: "Italy", dial: "+39" },
  { code: "JP", name: "Japan", dial: "+81" },
  { code: "JO", name: "Jordan", dial: "+962" },
  { code: "KE", name: "Kenya", dial: "+254" },
  { code: "KW", name: "Kuwait", dial: "+965" },
  { code: "MY", name: "Malaysia", dial: "+60" },
  { code: "MU", name: "Mauritius", dial: "+230" },
  { code: "MX", name: "Mexico", dial: "+52" },
  { code: "NP", name: "Nepal", dial: "+977" },
  { code: "NL", name: "Netherlands", dial: "+31" },
  { code: "NZ", name: "New Zealand", dial: "+64" },
  { code: "NG", name: "Nigeria", dial: "+234" },
  { code: "NO", name: "Norway", dial: "+47" },
  { code: "OM", name: "Oman", dial: "+968" },
  { code: "PK", name: "Pakistan", dial: "+92" },
  { code: "PH", name: "Philippines", dial: "+63" },
  { code: "PL", name: "Poland", dial: "+48" },
  { code: "PT", name: "Portugal", dial: "+351" },
  { code: "QA", name: "Qatar", dial: "+974" },
  { code: "RU", name: "Russia", dial: "+7" },
  { code: "SA", name: "Saudi Arabia", dial: "+966" },
  { code: "SG", name: "Singapore", dial: "+65" },
  { code: "ZA", name: "South Africa", dial: "+27" },
  { code: "KR", name: "South Korea", dial: "+82" },
  { code: "ES", name: "Spain", dial: "+34" },
  { code: "LK", name: "Sri Lanka", dial: "+94" },
  { code: "SE", name: "Sweden", dial: "+46" },
  { code: "CH", name: "Switzerland", dial: "+41" },
  { code: "TH", name: "Thailand", dial: "+66" },
  { code: "TR", name: "Türkiye", dial: "+90" },
  { code: "AE", name: "United Arab Emirates", dial: "+971" },
  { code: "GB", name: "United Kingdom", dial: "+44" },
  { code: "US", name: "United States", dial: "+1" },
  { code: "VN", name: "Vietnam", dial: "+84" },
];

export const DEFAULT_COUNTRY = "IN";

export function countryByCode(code: string): Country | undefined {
  return COUNTRIES.find((c) => c.code === code);
}

/**
 * Builds the E.164 number the rest of the system will carry.
 *
 * ─────────────────────────────────────────────────────────────────────
 *  THE FORMAT MATTERS DOWNSTREAM — DO NOT "SIMPLIFY" THIS
 * ─────────────────────────────────────────────────────────────────────
 *  The number reaches Wati through n8n, which normalises it as:
 *
 *      phone.replace(/\D/g, '').replace(/^(?!91)(\d{10})$/, '91$1')
 *
 *  Non-digits are stripped, and 91 is prepended ONLY to a bare
 *  ten-digit number. So "+919876543210" survives as "919876543210",
 *  and a foreign number keeps its own code. Sending the dial code is
 *  therefore safe, and sending a bare ten digits is only safe while
 *  every buyer is Indian — which is the assumption this form is
 *  removing.
 *
 *  The leading zero some people type out of habit (0 98765 43210) is
 *  dropped: it is a domestic trunk prefix and has no meaning in E.164.
 *  Left in, it would make an eleven-digit number that n8n leaves alone
 *  and Wati cannot deliver to.
 */
export function toE164(dial: string, localNumber: string): string {
  const digits = localNumber.replace(/\D/g, "").replace(/^0+/, "");
  return `${dial}${digits}`;
}
