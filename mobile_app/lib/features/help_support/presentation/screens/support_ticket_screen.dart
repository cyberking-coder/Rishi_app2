import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../application/help_providers.dart';
import '../../domain/entities/help_entities.dart';
import '../widgets/help_widgets.dart';

/// One request, as a conversation.
class SupportTicketScreen extends ConsumerStatefulWidget {
  const SupportTicketScreen({
    super.key,
    required this.ticketId,
    this.ticket,
  });

  final String ticketId;

  /// Passed through the route when arriving from the list, so the header
  /// can render immediately instead of after a round trip. Null on a cold
  /// deep link, which the header handles.
  final SupportTicket? ticket;

  @override
  ConsumerState<SupportTicketScreen> createState() =>
      _SupportTicketScreenState();
}

class _SupportTicketScreenState extends ConsumerState<SupportTicketScreen> {
  final _reply = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _reply.text.trim();
    if (body.isEmpty) return;

    setState(() => _sending = true);
    try {
      await ref
          .read(helpDataSourceProvider)
          .sendMessage(ticketId: widget.ticketId, body: body);
      _reply.clear();
      ref.invalidate(ticketMessagesProvider(widget.ticketId));
      // The ticket's updated_at moves, so the list order does too.
      ref.invalidate(myTicketsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send that. $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(ticketMessagesProvider(widget.ticketId));
    final ticket = widget.ticket;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(ticket == null ? 'Request' : '#${ticket.reference}'),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (ticket != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: AppTheme.glassSurface(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ticket.subject,
                        style: const TextStyle(
                          fontFamily: AppTheme.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.16,
                          height: 1.3,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TicketStatusChip(ticket.status),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: messagesAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.sage, strokeWidth: 2),
                ),
                error: (e, _) => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Could not load this conversation.',
                      style: TextStyle(
                          fontFamily: AppTheme.text,
                          color: AppTheme.textSecondary),
                    ),
                  ),
                ),
                data: (messages) => ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  itemCount: messages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _MessageBubble(message: messages[i]),
                ),
              ),
            ),
            _ReplyBar(
              controller: _reply,
              sending: _sending,
              onSend: _send,
              // A resolved ticket can still be replied to — that is how
              // somebody says "this came back". Nothing is gained by
              // making them open a second request for the same problem.
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final SupportMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = !message.fromStaff;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: mine
              ? BoxDecoration(
                  color: const Color(0x1A6D28D9),
                  borderRadius: BorderRadius.circular(AppTheme.radiusRow),
                )
              : AppTheme.glassSurface(),
          child: Column(
            crossAxisAlignment:
                mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                message.body,
                style: const TextStyle(
                  fontFamily: AppTheme.text,
                  fontSize: 14.5,
                  height: 1.5,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${mine ? 'You' : 'Support'} · ${helpAgo(message.createdAt)}',
                style: const TextStyle(
                  fontFamily: AppTheme.text,
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplyBar extends StatelessWidget {
  const _ReplyBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lifts with the keyboard. Without the viewInsets the reply box
      // sits underneath it, which is the one place in this screen a
      // member is guaranteed to be typing.
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        12 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 2, 6, 2),
        decoration: AppTheme.glassSurface(),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                  fontFamily: AppTheme.text,
                  fontSize: 15,
                  color: AppTheme.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: 'Type a message',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                  hintStyle: TextStyle(
                    fontFamily: AppTheme.text,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: sending ? null : onSend,
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, color: AppTheme.sageDark),
            ),
          ],
        ),
      ),
    );
  }
}
