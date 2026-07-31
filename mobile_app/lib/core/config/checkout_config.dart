/// Public URL of the deployed admin Next.js app, which also hosts the
/// external payment checkout page.
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
///   • Production:  https://rishi-app2.vercel.app
///   • A branch:    https://rishi-app2-git-<branch>-<team>.vercel.app
///
/// Override at build time without editing this file:
///   flutter run --dart-define=CHECKOUT_BASE_URL=https://…
const String checkoutBaseUrl = String.fromEnvironment(
  'CHECKOUT_BASE_URL',
  defaultValue: 'https://rishi-app2.vercel.app',
);

bool get isCheckoutConfigured =>
    checkoutBaseUrl.isNotEmpty && !checkoutBaseUrl.startsWith('REPLACE_WITH_');
