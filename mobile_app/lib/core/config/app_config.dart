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

  /// The version a support ticket reports.
  ///
  /// ───────────────────────────────────────────────────────────────────
  ///  KEEP IN SYNC WITH the `version:` line in pubspec.yaml
  /// ───────────────────────────────────────────────────────────────────
  ///  A constant rather than package_info_plus, which would be a new
  /// dependency, a plugin channel and an async call on a screen that has
  /// no other reason to be async — all to read a number that is already
  /// written down in this repository.
  ///
  /// It is the marketing version only, not the build number: Codemagic
  /// overrides the build number with its own counter, so a build number
  /// compiled in here would be wrong on every CI build. If a ticket needs
  /// to be pinned to an exact build, the OS version and device in the
  /// same payload plus the ticket's timestamp will narrow it.
  static const appVersion = '2.2.1';

  static const audioChannelId = 'com.knowthyself.app.audio.channel';
  static const audioChannelName = 'Meditation Audio';
}
