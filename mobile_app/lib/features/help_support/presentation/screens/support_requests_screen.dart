import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../application/help_providers.dart';
import '../../domain/entities/help_entities.dart';
import '../widgets/help_widgets.dart';

/// Every request this member has opened.
class SupportRequestsScreen extends ConsumerWidget {
  const SupportRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myTicketsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('My requests'),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppTheme.sage,
          onRefresh: () async => ref.invalidate(myTicketsProvider),
          child: async.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                  color: AppTheme.sage, strokeWidth: 2),
            ),
            error: (e, _) => ListView(
              padding: const EdgeInsets.all(20),
              children: const [
                Text(
                  'Could not load your requests. Pull down to try again.',
                  style: TextStyle(
                      fontFamily: AppTheme.text,
                      color: AppTheme.textSecondary),
                ),
              ],
            ),
            data: (tickets) {
              if (tickets.isEmpty) {
                // Always scrollable, so pull-to-refresh still works on an
                // empty list — otherwise there is no gesture to retry with.
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                  children: const [
                    Icon(Icons.inbox_outlined,
                        size: 40, color: AppTheme.textSecondary),
                    SizedBox(height: 14),
                    Text(
                      'You have not asked us anything yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTheme.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'When you contact support, the conversation will '
                      'appear here so you can follow it.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTheme.text,
                        fontSize: 13,
                        height: 1.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                itemCount: tickets.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _TicketTile(ticket: tickets[i]),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket});
  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(
        '/help-support/requests/${ticket.id}',
        extra: ticket,
      ),
      borderRadius: BorderRadius.circular(AppTheme.radiusRow),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.glassSurface(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    ticket.subject,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTheme.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.15,
                      height: 1.3,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                TicketStatusChip(ticket.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '#${ticket.reference} · updated ${helpAgo(ticket.updatedAt)}',
              style: const TextStyle(
                fontFamily: AppTheme.text,
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
