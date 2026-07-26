/// App-wide configuration.
///
/// Replace the two placeholder values below with your Supabase project
/// credentials before running the app.
///
/// Where to find them:
///   1. Go to https://supabase.com and open your project.
///   2. Settings → API
///   3. Copy "Project URL" → supabaseUrl
///   4. Copy "anon / public" key → supabaseAnonKey
class AppConfig {
  static const supabaseUrl = 'https://gzcanqovqirarnculqjq.supabase.co';
  static const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd6Y2FucW92cWlyYXJuY3VscWpxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE4MzcwMTgsImV4cCI6MjA5NzQxMzAxOH0.dYb9l9LkBRa5oVnElSswOEIJB_EeE51nBGsWGwr1ZEM';

  static const appName = 'Know Thyself';
  static const audioChannelId = 'com.knowthyself.app.audio.channel';
  static const audioChannelName = 'Meditation Audio';

  /// Deep link Supabase redirects back to once a browser-based OAuth flow
  /// (e.g. Google) completes, or once a signup confirmation email link is
  /// tapped. Shares the `meditationapp://` scheme already registered for
  /// password-reset emails; must also be added to the Supabase project's
  /// Authentication > URL Configuration redirect list.
  static const authRedirectUrl = 'meditationapp://login-callback';

  /// Deep link for password-reset emails — the intent-filter/URL-type for
  /// this host already exists natively; this was previously never passed
  /// explicitly, so reset emails fell back to Supabase's default Site URL.
  static const passwordResetRedirectUrl = 'meditationapp://reset-password';
}
