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
  static const supabaseUrl = 'https://YOUR_PROJECT_ID.supabase.co';
  static const supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  static const appName = 'Meditation App';
  static const audioChannelId = 'com.meditation.app.audio.channel';
  static const audioChannelName = 'Meditation Audio';
}
