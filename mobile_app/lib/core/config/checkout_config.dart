/// Public URL of the deployed admin Next.js app, which also hosts the
/// external payment checkout page.
///
/// MUST be a subdomain of a domain Razorpay has approved under Account &
/// Settings -> Website and app details. Checkout run from anywhere else
/// shows the buyer an "this website is not verified" interstitial in the
/// middle of paying, which is the single most expensive place in the
/// whole app to lose someone's confidence. anuragrishi.com is approved;
/// the bare *.vercel.app host never can be, because ownership of a
/// shared apex domain cannot be proved.
///
/// This MUST be a stable alias, never a per-deployment URL. Vercel gives
/// every build its own immutable URL containing a hash, e.g.
///
///   https://rishi-app2-84t94jdyl-ritesh-s-projects9.vercel.app
///                      ^^^^^^^^^ pinned to one build, forever
///
/// Pointing the app at one of those freezes checkout on whatever the
/// page looked like the day it was pasted: later deploys never reach
/// users, and the symptom is a checkout page that stubbornly refuses to
/// pick up any change. Use an alias that tracks the latest build:
///
///   • Production:  https://pay.anuragrishi.com  (CNAME -> Vercel)
///   • A branch:    https://rishi-app2-git-<branch>-<team>.vercel.app
///                  (fine for testing; Razorpay will warn on it)
///
/// Override at build time without editing this file:
///   flutter run --dart-define=CHECKOUT_BASE_URL=https://…
const String checkoutBaseUrl = String.fromEnvironment(
  'CHECKOUT_BASE_URL',
  defaultValue: 'https://pay.anuragrishi.com',
);

bool get isCheckoutConfigured =>
    checkoutBaseUrl.isNotEmpty && !checkoutBaseUrl.startsWith('REPLACE_WITH_');
