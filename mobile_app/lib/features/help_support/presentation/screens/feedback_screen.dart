import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../application/help_providers.dart';
import '../../domain/entities/help_entities.dart';

/// Feedback, which is not a support request.
///
/// Kept separate from tickets deliberately, unlike "Report a problem"
/// which is folded into them. A ticket is a question someone is waiting
/// on an answer to; feedback is not, and filing it in the same queue
/// would either create a backlog of things nobody needs to reply to, or
/// train the team to leave tickets unanswered.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _message = TextEditingController();
  FeedbackType _type = FeedbackType.general;

  /// 0 means "not rated". Optional on purpose — somebody with a specific
  /// suggestion should not have to score the whole app to leave it.
  int _rating = 0;
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final message = _message.text.trim();
    if (message.isEmpty) {
      _say('Tell us a little about it first.');
      return;
    }

    setState(() => _sending = true);
    try {
      await ref.read(helpDataSourceProvider).submitFeedback(
            type: _type,
            message: message,
            rating: _rating == 0 ? null : _rating,
          );
      if (!mounted) return;
      context.pop();
      _say('Thank you — this reaches the people building the app.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      _say('Could not send that. $e');
    }
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Send feedback'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const Text(
              'This is not a support request — nobody will reply. If you '
              'need an answer, use Contact support instead.',
              style: TextStyle(
                fontFamily: AppTheme.text,
                fontSize: 13.5,
                height: 1.5,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in FeedbackType.values)
                  ChoiceChip(
                    label: Text(type.label),
                    selected: _type == type,
                    onSelected: (_) => setState(() => _type = type),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            Container(
              decoration: AppTheme.glassSurface(),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: TextField(
                controller: _message,
                maxLines: 7,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                  fontFamily: AppTheme.text,
                  fontSize: 15,
                  height: 1.45,
                  color: AppTheme.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: 'What would you like to tell us?',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                  hintStyle: TextStyle(
                    fontFamily: AppTheme.text,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),

            const Text(
              'How has the app been for you? (optional)',
              style: TextStyle(
                fontFamily: AppTheme.text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var star = 1; star <= 5; star++)
                  IconButton(
                    onPressed: () => setState(
                      // Tapping the current rating clears it, so a rating
                      // given by accident can be taken back.
                      () => _rating = _rating == star ? 0 : star,
                    ),
                    icon: Icon(
                      star <= _rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 30,
                      color: star <= _rating
                          ? AppTheme.sageDark
                          : AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 22),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _sending ? null : _submit,
                child: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Send feedback'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
