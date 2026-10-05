import 'dart:io' show Platform;

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
  ///  KEEP IN SYNC WITH the store version for each platform.
  /// ───────────────────────────────────────────────────────────────────
  ///  The two stores carry DIFFERENT marketing versions: Play Store is
  /// 3.0.0 (pinned in android/app/build.gradle), the App Store is 2.2.9
  /// (the pubspec version iOS uses). So this is per-platform rather than a
  /// single const, so a support ticket reports the version the user
  /// actually sees in their store.
  ///
  ///  Still the marketing version only, not the build number: Codemagic
  /// overrides the build number with its own counter, so a build number
  /// compiled in here would be wrong on every CI build.
  static String get appVersion => Platform.isAndroid ? '3.0.0' : '2.2.9';

  static const audioChannelId = 'com.knowthyself.app.audio.channel';
  static const audioChannelName = 'Meditation Audio';
}
