/// Public URL of the deployed admin Next.js app, which also hosts the
/// external payment checkout page (e.g. https://admin.yourapp.com).
/// Update this once the admin app is deployed — no other app code needs
/// to change.
const String checkoutBaseUrl = 'REPLACE_WITH_YOUR_ADMIN_APP_URL';

bool get isCheckoutConfigured => !checkoutBaseUrl.startsWith('REPLACE_WITH_');
