import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/supabase_client_provider.dart';
import '../data/access_remote_datasource.dart';
import '../domain/access_state.dart';

final accessRemoteDataSourceProvider = Provider<AccessRemoteDataSource>((ref) {
  return AccessRemoteDataSource(ref.watch(supabaseClientProvider));
});

/// The user's current access window + pop-up config. Re-fetched whenever the
/// home screen mounts so an admin-side expiry/extension takes effect promptly.
final accessStateProvider = FutureProvider.autoDispose<AccessState>((ref) {
  return ref.watch(accessRemoteDataSourceProvider).fetch();
});
