/// Public URL of the deployed admin Next.js app, which also hosts the
/// external payment checkout page (e.g. https://admin.yourapp.com).
/// Update this once the admin app is deployed — no other app code needs
/// to change.
const String checkoutBaseUrl =
    'https://rishi-app2-84t94jdyl-ritesh-s-projects9.vercel.app';

bool get isCheckoutConfigured => !checkoutBaseUrl.startsWith('REPLACE_WITH_');
