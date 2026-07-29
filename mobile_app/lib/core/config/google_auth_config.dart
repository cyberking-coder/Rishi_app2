/// The OAuth 2.0 **Web** client ID from Google Cloud Console, used as
/// `serverClientId` so `google_sign_in` returns an ID token Supabase can
/// verify server-side. This is NOT the Android or iOS client ID.
///
/// Create it at https://console.cloud.google.com/apis/credentials
/// (APIs & Services -> Credentials -> Create Credentials -> OAuth client ID
/// -> Application type: Web application), then paste the client ID below.
/// See mobile_app/README or the Phase 1 setup notes for the full checklist
/// (Android SHA-1 registration, iOS URL scheme, Supabase provider config).
const String googleWebClientId =
    'REPLACE_WITH_GOOGLE_CLOUD_WEB_CLIENT_ID.apps.googleusercontent.com';

bool get isGoogleSignInConfigured =>
    !googleWebClientId.startsWith('REPLACE_WITH_');
