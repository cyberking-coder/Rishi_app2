import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/speech/speech_service.dart';
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
  final _speech = SpeechService();

  bool _listening = false;

  /// Whatever was already typed when the microphone opened. Dictation is
  /// appended to it rather than replacing it, so tapping the mic to
  /// finish a half-typed sentence does what it looks like it will.
  String _textBeforeListening = '';

  @override
  void dispose() {
    _speech.dispose();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    _textBeforeListening = _controller.text.trimRight();
    setState(() => _listening = true);

    await _speech.start(
      onText: (text) {
        if (!mounted) return;
        final joined = _textBeforeListening.isEmpty
            ? text
            : '$_textBeforeListening $text';
        _controller.value = TextEditingValue(
          text: joined,
          // Caret pinned to the end as the text grows, so the field
          // scrolls with the speech instead of showing the beginning of
          // a sentence that has moved on.
          selection: TextSelection.collapsed(offset: joined.length),
        );
      },
      onDone: () {
        if (mounted) setState(() => _listening = false);
      },
      onError: (message) {
        if (mounted) setState(() => _listening = false);
        _notify(message);
      },
    );
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
    // Sending while the microphone is open would leave it listening into
    // an empty field and quietly refill it with the tail of the same
    // sentence.
    if (_listening) {
      _speech.stop();
      setState(() => _listening = false);
    }
    _controller.clear();
    _textBeforeListening = '';
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
            if (_listening) const _ListeningBar(),
            _Composer(
              controller: _controller,
              enabled: !state.sending && state.limitMessage == null,
              onSend: _send,
              listening: _listening,
              onMic: state.limitMessage == null ? _toggleMic : null,
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
          'when it is not working. Type it, or tap the microphone and '
          'just say it.',
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

/// The bar that appears above the composer while the microphone is open.
///
/// Not a subtle state change on the button alone: an open microphone is
/// the one thing on this screen a user must never be unsure about.
class _ListeningBar extends StatelessWidget {
  const _ListeningBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.sageSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusRow),
      ),
      child: const Row(
        children: [
          _PulsingDot(),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Listening… speak your question, then tap the mic to stop.',
              style: TextStyle(
                fontFamily: AppTheme.text,
                fontSize: 12.5,
                height: 18 / 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.sageDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A dot that breathes. Cheap, and the only moving thing on the screen
/// while the microphone is open, so it carries the whole signal.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_pulse),
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: AppTheme.danger,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final void Function(String) onSend;
  final bool listening;

  /// Null when dictation should be unavailable — the allowance is spent,
  /// so there is nothing to dictate into.
  final VoidCallback? onMic;

  const _Composer({
    required this.controller,
    required this.enabled,
    required this.onSend,
    required this.listening,
    required this.onMic,
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
                decoration: InputDecoration(
                  hintText:
                      listening ? 'Listening…' : 'Ask the guide…',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Dictation. Deliberately does not send when speech ends: the
          // recogniser mishears names and Hindi words often enough that
          // auto-sending would spend one of the day's twenty questions on
          // a garbled sentence the user never got to read.
          GestureDetector(
            onTap: onMic,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: listening ? AppTheme.danger : AppTheme.sageSoft,
                shape: BoxShape.circle,
                boxShadow: listening ? AppTheme.rowShadow : null,
              ),
              child: Icon(
                listening ? Icons.stop_rounded : Icons.mic_none_rounded,
                color: listening ? Colors.white : AppTheme.sageDark,
                size: 23,
              ),
            ),
          ),
          const SizedBox(width: 8),
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
