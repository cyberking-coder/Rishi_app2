import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/config/purchase_config.dart';
import '../../application/help_providers.dart';
import '../../domain/entities/help_entities.dart';
import 'help_support_screen.dart' show ContactArgs;

/// The form that opens a ticket.
///
/// Also serves "Report a problem" — same fields, same table, same person
/// answering. [ContactArgs.problemReport] changes the wording and
/// preselects Technical; it does not change what is stored, because a
/// second table for the same object would only mean two inboxes to
/// forget to check.
class ContactSupportScreen extends ConsumerStatefulWidget {
  const ContactSupportScreen({super.key, this.args});
  final ContactArgs? args;

  @override
  ConsumerState<ContactSupportScreen> createState() =>
      _ContactSupportScreenState();
}

class _ContactSupportScreenState extends ConsumerState<ContactSupportScreen> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  /// Falls back to `other` when the preset category is one this platform
  /// does not offer. Unreachable today — the only way to arrive with
  /// `membership` preset is from a membership article, which iOS does not
  /// show — but a selected chip that is not in the list would render as
  /// nothing selected, and that is a confusing way to find out.
  late HelpCategory _category = _initialCategory();

  HelpCategory _initialCategory() {
    final preset = widget.args?.category;
    if (preset == null) return HelpCategory.other;
    if (!kPurchaseUiEnabled && preset == HelpCategory.membership) {
      return HelpCategory.other;
    }
    return preset;
  }
  bool _sending = false;

  bool get _isProblem => widget.args?.problemReport ?? false;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subject.text.trim();
    final message = _message.text.trim();

    if (subject.isEmpty) {
      _say('Give it a short subject so we can find it again.');
      return;
    }
    if (message.length < 10) {
      // Ten characters, not one. "Broken" tells support nothing and
      // guarantees a round trip before anything can be looked at.
      _say('Please describe what happened in a little more detail.');
      return;
    }

    setState(() => _sending = true);
    try {
      await ref.read(helpDataSourceProvider).createTicket(
            category: _category,
            subject: subject,
            body: message,
          );
      // The list is autoDispose and re-read on open, but this screen pops
      // straight back onto it — invalidate so the new ticket is there
      // rather than appearing a beat later.
      ref.invalidate(myTicketsProvider);
      if (!mounted) return;
      context.pop();
      _say('Sent. We will reply to the email on your account.');
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
        title: Text(_isProblem ? 'Report a problem' : 'Contact support'),
      ),
      // resizeToAvoidBottomInset plus a scroll view: the message box is
      // near the bottom, and on a small handset the keyboard covers it
      // otherwise.
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              _isProblem
                  ? 'Tell us what went wrong. Your app version, device and '
                      'OS version are attached automatically — you do not '
                      'need to look them up.'
                  : 'We reply to the email address on your account.',
              style: const TextStyle(
                fontFamily: AppTheme.text,
                fontSize: 13.5,
                height: 1.5,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            const _FieldLabel('What is it about?'),
            _CategoryPicker(
              value: _category,
              onChanged: (c) => setState(() => _category = c),
            ),
            const SizedBox(height: 18),

            const _FieldLabel('Subject'),
            _Field(
              controller: _subject,
              hint: _isProblem ? 'Audio stops after a minute' : 'Short summary',
              maxLines: 1,
            ),
            const SizedBox(height: 18),

            _FieldLabel(_isProblem ? 'What happened?' : 'Message'),
            _Field(
              controller: _message,
              hint: _isProblem
                  ? 'What you were doing, and what the app did.'
                  : 'Describe your issue',
              maxLines: 7,
            ),
            const SizedBox(height: 24),

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
                    : Text(_isProblem ? 'Report problem' : 'Send request'),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Never include your password or card details. We will never '
              'ask for them.',
              style: TextStyle(
                fontFamily: AppTheme.text,
                fontSize: 12,
                height: 1.45,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: AppTheme.text,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.maxLines,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.glassSurface(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(
          fontFamily: AppTheme.text,
          fontSize: 15,
          height: 1.45,
          color: AppTheme.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          hintStyle: const TextStyle(
            fontFamily: AppTheme.text,
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.value, required this.onChanged});
  final HelpCategory value;
  final ValueChanged<HelpCategory> onChanged;

  static const _labels = {
    HelpCategory.content: 'Content & playback',
    HelpCategory.account: 'Account & login',
    HelpCategory.membership: 'Membership & payments',
    HelpCategory.technical: 'Technical issue',
    HelpCategory.other: 'Something else',
  };

  /// Membership is not offered as a category on iOS, for the same reason
  /// its help articles are not shown there — see
  /// Faq.isAllowedOnThisPlatform.
  ///
  /// Nobody loses a route: a billing question still reaches support under
  /// "Something else", with the member's own words rather than a label
  /// the app supplied. What is removed is the app naming payments.
  static Map<HelpCategory, String> get _visibleLabels => {
        for (final e in _labels.entries)
          if (kPurchaseUiEnabled || e.key != HelpCategory.membership)
            e.key: e.value,
      };

  @override
  Widget build(BuildContext context) {
    // Chips rather than a dropdown. Five options fit on two lines, and a
    // dropdown on a phone is a modal that hides the form behind it to
    // choose one of five things.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in _visibleLabels.entries)
          ChoiceChip(
            label: Text(entry.value),
            selected: value == entry.key,
            onSelected: (_) => onChanged(entry.key),
          ),
      ],
    );
  }
}
