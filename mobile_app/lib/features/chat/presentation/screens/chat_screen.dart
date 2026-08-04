import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../application/chat_providers.dart';
import '../../domain/entities/chat_message.dart';

/// Openers for an empty screen.
///
/// Not decoration: an empty chat with a blinking cursor asks the user to
/// invent the use case, and most people close it instead. These are the
/// three things this assistant is actually for.
const _openers = [
  'I have never meditated. Where do I start?',
  'Which order should I play these in?',
  'I cannot stop my thoughts. Am I doing it wrong?',
];

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    // After the frame, because the new bubble has no height until it has
    // been laid out and jumping before that lands short of the bottom.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  void _send(String text) {
    _controller.clear();
    ref.read(chatControllerProvider.notifier).send(text);
    _scrollToEnd();
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        ),
        title: const Text('Clear this conversation?', style: AppTheme.headline),
        content: const Text(
          'Everything you have asked here will be deleted. This cannot be '
          'undone.',
          style: AppTheme.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(chatControllerProvider.notifier).clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider);

    ref.listen(chatControllerProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length) _scrollToEnd();
    });

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Guide'),
        actions: [
          if (state.messages.isNotEmpty)
            IconButton(
              onPressed: _confirmClear,
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Clear conversation',
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: state.loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.sage),
                    )
                  : state.messages.isEmpty
                      ? _Empty(onPick: _send)
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount:
                              state.messages.length + (state.sending ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (i == state.messages.length) {
                              return const _Thinking();
                            }
                            return _Bubble(
                              message: state.messages[i],
                              onRetry: () => ref
                                  .read(chatControllerProvider.notifier)
                                  .retry(),
                            );
                          },
                        ),
            ),
            if (state.limitMessage != null)
              _Notice(text: state.limitMessage!)
            // The counter appears only in the last few messages. Showing
            // "17 left" from the first question turns a conversation into
            // a metered service, which is the opposite of the tone here.
            else if (state.remaining != null && state.remaining! <= 3)
              _Notice(
                text: state.remaining == 0
                    ? 'That was your last question for today.'
                    : '${state.remaining} more questions today.',
                soft: true,
              ),
            _Composer(
              controller: _controller,
              enabled: !state.sending && state.limitMessage == null,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────

class _Empty extends StatelessWidget {
  final void Function(String) onPick;

  const _Empty({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              gradient: AppTheme.sageGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.self_improvement_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Ask anything about your practice',
          textAlign: TextAlign.center,
          style: AppTheme.headline,
        ),
        const SizedBox(height: 10),
        const Text(
          'How to sit, how long for, what to play next — and what to do '
          'when it is not working.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.text,
            fontSize: 14.5,
            height: 22 / 14.5,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 28),
        for (final opener in _openers)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => onPick(opener),
              borderRadius: BorderRadius.circular(AppTheme.radiusRow),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: AppTheme.claySurface(
                  color: AppTheme.surfaceCream,
                  radius: AppTheme.radiusRow,
                  small: true,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(opener, style: AppTheme.body),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.north_east_rounded,
                        size: 16, color: AppTheme.sage),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Bubbles ──────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onRetry;

  const _Bubble({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final width = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: width * 0.82),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              // The user's own words sit on sage; the guide answers on
              // cream. Reversing it would put the app's voice in the
              // brand colour and the person's in the background, which
              // is the wrong way round for a screen about listening.
              color: isUser ? AppTheme.sage : AppTheme.surfaceCream,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(AppTheme.radiusRow),
                topRight: const Radius.circular(AppTheme.radiusRow),
                bottomLeft: Radius.circular(isUser ? AppTheme.radiusRow : 6),
                bottomRight: Radius.circular(isUser ? 6 : AppTheme.radiusRow),
              ),
              boxShadow: isUser ? null : AppTheme.rowShadow,
            ),
            child: SelectableText(
              message.text,
              style: TextStyle(
                fontFamily: AppTheme.text,
                fontSize: 15,
                height: 23 / 15,
                color: isUser ? AppTheme.textOnSage : AppTheme.textPrimary,
              ),
            ),
          ),
          if (message.links.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final link in message.links) _LinkChip(link: link),
              ],
            ),
          ],
          if (message.error != null) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    message.error!,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontFamily: AppTheme.text,
                      fontSize: 12,
                      color: AppTheme.danger,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LinkChip extends StatelessWidget {
  final ChatLink link;

  const _LinkChip({required this.link});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      // push, not go: the chat is a drill-down and the back button should
      // return to it rather than to the tab underneath.
      onTap: () => context.push(link.route, extra: link.label),
      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppTheme.sageSoft,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              link.kind == 'course'
                  ? Icons.school_rounded
                  : Icons.play_arrow_rounded,
              size: 16,
              color: AppTheme.sageDark,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(
                link.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTheme.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.sageDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCream,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppTheme.radiusRow),
              topRight: Radius.circular(AppTheme.radiusRow),
              bottomLeft: Radius.circular(6),
              bottomRight: Radius.circular(AppTheme.radiusRow),
            ),
            boxShadow: AppTheme.rowShadow,
          ),
          child: const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.sage,
            ),
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final String text;
  final bool soft;

  const _Notice({required this.text, this.soft = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: soft ? AppTheme.sageSoft : AppTheme.sandSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusRow),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: AppTheme.text,
          fontSize: 12.5,
          height: 18 / 12.5,
          fontWeight: FontWeight.w600,
          color: soft ? AppTheme.sageDark : AppTheme.clay,
        ),
      ),
    );
  }
}

// ── Composer ─────────────────────────────────────────────────────────

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final void Function(String) onSend;

  const _Composer({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        gradient: AppTheme.clayFill(),
        boxShadow: AppTheme.navShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: AppTheme.clayInset(radius: AppTheme.radiusRow),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: enabled ? onSend : null,
                style: AppTheme.body,
                decoration: const InputDecoration(
                  hintText: 'Ask the guide…',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Rebuilt on every keystroke so the button can dim while the
          // field is empty — a send button that looks live and does
          // nothing is worse than one that looks off.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final ready = enabled && value.text.trim().isNotEmpty;
              return GestureDetector(
                onTap: ready ? () => onSend(value.text) : null,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: ready ? AppTheme.sage : AppTheme.sageLight,
                    shape: BoxShape.circle,
                    boxShadow: ready ? AppTheme.rowShadow : null,
                  ),
                  child: const Icon(
                    Icons.arrow_upward_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
