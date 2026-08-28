import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/supabase_client_provider.dart';
import '../data/help_remote_datasource.dart';
import '../domain/entities/help_entities.dart';

final helpDataSourceProvider = Provider<HelpRemoteDataSource>((ref) {
  return HelpRemoteDataSource(ref.watch(supabaseClientProvider));
});

/// Every published FAQ.
///
/// keepAlive because the whole list is fetched once and then searched and
/// filtered locally — dropping it on navigation would mean re-fetching
/// the same few dozen rows every time somebody backed out of an answer.
final faqsProvider = FutureProvider.autoDispose<List<Faq>>((ref) {
  ref.keepAlive();
  return ref.watch(helpDataSourceProvider).getFaqs();
});

/// This user's tickets, most recently updated first.
///
/// Deliberately NOT keepAlive. A ticket's status changes on the support
/// team's side, so this is exactly the list that should be re-read every
/// time it is opened — staleness here means telling somebody "In
/// progress" about something resolved yesterday.
final myTicketsProvider =
    FutureProvider.autoDispose<List<SupportTicket>>((ref) {
  return ref.watch(helpDataSourceProvider).getMyTickets();
});

final ticketMessagesProvider =
    FutureProvider.autoDispose.family<List<SupportMessage>, String>(
  (ref, ticketId) => ref.watch(helpDataSourceProvider).getMessages(ticketId),
);
