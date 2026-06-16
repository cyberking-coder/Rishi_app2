import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Initialized once in main.dart via Supabase.initialize(...).
/// Exposed as a provider so the data layer never imports the SDK directly
/// outside of datasources.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
