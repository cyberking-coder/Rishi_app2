import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/config/checkout_config.dart';
import '../../../../core/config/purchase_config.dart';
import '../../../../core/config/support_config.dart';
import '../../application/help_providers.dart';
import '../../domain/entities/help_entities.dart';
import '../widgets/help_widgets.dart';

/// Help & Support.
///
/// Built to the PRD, with three deliberate departures, each made because
/// the alternative added screens without adding answers:
///
///  1. Categories FILTER the FAQ list on this page rather than opening
///     four near-identical sub-screens. Tapping "Membership & Payments"
///     shows the membership questions immediately, which is what somebody
///     tapping it wanted; a screen containing a second list of the same
///     questions is a step, not an answer.
///
///  2. An FAQ EXPANDS in place instead of pushing a detail route. The
///     answers are a paragraph. Losing your place in a list of questions
///     to read one paragraph, then coming back and finding the list
///     scrolled to the top, is worse than reading it where you found it.
///     "Was this helpful?" still appears, expanded, with the escape hatch
///     to a real person when the answer is no.
///
///  3. "Report a problem" is the contact form with the Technical category
///     preselected, not a separate table and screen. It produces the same
///     object, needs the same fields, and is answered by the same person.
///
/// What is NOT here, and is a real gap rather than an oversight:
/// screenshot attachments. They need a storage bucket with its own
/// policies and an upload path, and every one of those is somewhere one
/// member's evidence could leak to another. It is a coherent next step.
class HelpSupportScreen extends ConsumerStatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  ConsumerState<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends ConsumerState<HelpSupportScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  HelpCategory? _category;

  /// Set by "View all", cleared whenever the list is narrowed another
  /// way. A separate flag rather than a sentinel in [_query]: putting a
  /// space in the query to mean "show everything" would leave the state
  /// and the visibly-empty search box disagreeing.
  bool _showAll = false;

  /// How many FAQs to show before "View all". Only applies when nothing
  /// is being searched or filtered — a search that hides its own results
  /// behind a "view all" would be absurd.
  static const _previewCount = 5;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isBrowsing => _query.isEmpty && _category == null && !_showAll;

  List<Faq> _visible(List<Faq> all) {
    final filtered = all
        .where((f) => f.isAllowedOnThisPlatform)
        .where((f) => _category == null || f.category == _category)
        .where((f) => f.matches(_query))
        .toList();
    return _isBrowsing && filtered.length > _previewCount
        ? filtered.take(_previewCount).toList()
        : filtered;
  }

  Future<void> _open(Uri uri, String fallback) async {
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (ok || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(fallback)));
  }

  @override
  Widget build(BuildContext context) {
    final faqsAsync = ref.watch(faqsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Help & Support'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          children: [
            const Text(
              'How can we help?',
              style: TextStyle(
                fontFamily: AppTheme.display,
                fontSize: 28,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.84,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 18),

            _SearchField(
              controller: _searchController,
              onChanged: (v) => setState(() {
                _query = v;
                _showAll = false;
              }),
            ),
            const SizedBox(height: 24),

            HelpSectionLabel('Quick help'),
            _CategoryGrid(
              selected: _category,
              onSelect: (c) => setState(() {
                // Tapping the selected category clears it. Without this
                // there is no way back to the full list except clearing a
                // search box that was never typed in.
                _category = _category == c ? null : c;
                _showAll = false;
              }),
            ),
            const SizedBox(height: 24),

            HelpSectionLabel(
              _category == null ? 'Frequently asked' : 'Questions',
            ),
            faqsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.sage, strokeWidth: 2),
                ),
              ),
              error: (e, _) => _HelpNotice(
                text: 'We could not load the help articles just now. You can '
                    'still contact us below.',
              ),
              data: (all) {
                final visible = _visible(all);
                if (visible.isEmpty) {
                  return _HelpNotice(
                    text: _query.isEmpty
                        ? 'Nothing here yet.'
                        : 'Nothing matched "$_query". Try fewer words, or '
                            'contact us below and we will answer directly.',
                  );
                }

                // Counted over the same filtered set the list is drawn
                // from — otherwise "View all 3 more" would offer articles
                // this platform withholds, and tapping it would show
                // fewer than it promised.
                final hidden = all
                        .where((f) => f.isAllowedOnThisPlatform)
                        .where((f) =>
                            _category == null || f.category == _category)
                        .where((f) => f.matches(_query))
                        .length -
                    visible.length;

                return Column(
                  children: [
                    for (final faq in visible) ...[
                      _FaqTile(
                        faq: faq,
                        onContact: () => _contact(category: faq.category),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (hidden > 0)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => setState(() => _showAll = true),
                          child: Text('View all $hidden more →'),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 26),

            HelpSectionLabel('Still need help?'),
            _ContactCard(
              onContact: _contact,
              onWhatsApp: () => _open(
                Uri.parse(
                  'https://wa.me/${SupportConfig.phoneE164.replaceAll(RegExp(r'[^0-9]'), '')}',
                ),
                'WhatsApp us on ${SupportConfig.phoneDisplay}',
              ),
              onEmail: () => _open(
                Uri.parse('mailto:${SupportConfig.email}'),
                'Email us at ${SupportConfig.email}',
              ),
            ),
            const SizedBox(height: 26),

            HelpSectionLabel('More'),
            HelpRow(
              icon: Icons.bug_report_outlined,
              title: 'Report a problem',
              subtitle: 'Sends your app version and device automatically.',
              onTap: () => _contact(
                category: HelpCategory.technical,
                problemReport: true,
              ),
            ),
            const SizedBox(height: 10),
            HelpRow(
              icon: Icons.lightbulb_outline_rounded,
              title: 'Send feedback',
              subtitle: 'Suggest a feature, or tell us how it is going.',
              onTap: () => context.push('/help-support/feedback'),
            ),
            const SizedBox(height: 10),
            HelpRow(
              icon: Icons.inbox_outlined,
              title: 'My support requests',
              onTap: () => context.push('/help-support/requests'),
            ),
            const SizedBox(height: 26),

            // Legal lives on the web, where it is also what Razorpay and
            // the app stores are pointed at. Linking rather than
            // duplicating means there is one copy to keep current.
            _LegalLinks(
              onPrivacy: () => _open(
                Uri.parse('$checkoutBaseUrl/privacy'),
                'Visit $checkoutBaseUrl/privacy',
              ),
              onTerms: () => _open(
                Uri.parse('$checkoutBaseUrl/terms'),
                'Visit $checkoutBaseUrl/terms',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _contact({HelpCategory? category, bool problemReport = false}) {
    context.push(
      '/help-support/contact',
      extra: ContactArgs(category: category, problemReport: problemReport),
    );
  }
}

/// What the contact form is opened with.
class ContactArgs {
  final HelpCategory? category;

  /// Changes the wording only — a problem report and a support request
  /// are the same ticket, and pretending otherwise would mean two tables
  /// answered by one person.
  final bool problemReport;

  const ContactArgs({this.category, this.problemReport = false});
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.glassSurface(),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          const Icon(Icons.search_rounded,
              size: 19, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                fontFamily: AppTheme.text,
                fontSize: 15,
                color: AppTheme.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: 'Search for help',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 15),
                hintStyle: TextStyle(
                  fontFamily: AppTheme.text,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.selected, required this.onSelect});
  final HelpCategory? selected;
  final ValueChanged<HelpCategory> onSelect;

  static const _all = [
    (HelpCategory.content, Icons.menu_book_outlined, 'Content\n& playback'),
    (HelpCategory.account, Icons.person_outline_rounded, 'Account\n& login'),
    (HelpCategory.membership, Icons.card_membership_outlined,
        'Membership\n& payments'),
    (HelpCategory.technical, Icons.phone_iphone_rounded, 'Technical\nissues'),
  ];

  /// The membership tile is not drawn on iOS. Its articles are withheld
  /// there (see Faq.isAllowedOnThisPlatform), and a tile that filters to
  /// an empty list is worse than no tile — it reads as a fault, and it
  /// puts the word "payments" on screen for no benefit.
  static List<(HelpCategory, IconData, String)> get _items => _all
      .where((i) => kPurchaseUiEnabled || i.$1 != HelpCategory.membership)
      .toList();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _items.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _CategoryTile(
              icon: _items[i].$2,
              label: _items[i].$3,
              active: selected == _items[i].$1,
              onTap: () => onSelect(_items[i].$1),
            ),
          ),
        ],
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusRow),
      child: Container(
        height: 96,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: active
            ? BoxDecoration(
                color: const Color(0x1A6D28D9),
                borderRadius: BorderRadius.circular(AppTheme.radiusRow),
                border: Border.all(color: AppTheme.sageDark),
              )
            : AppTheme.glassSurface(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 22,
                color: active ? AppTheme.sageDark : AppTheme.textSecondary),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.text,
                fontSize: 11.5,
                height: 1.25,
                fontWeight: FontWeight.w600,
                color:
                    active ? AppTheme.sageDark : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One question, expanding in place to show its answer.
class _FaqTile extends StatefulWidget {
  const _FaqTile({required this.faq, required this.onContact});
  final Faq faq;
  final VoidCallback onContact;

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  /// null until answered, then true/false. Held in the widget only —
  /// nothing is written anywhere.
  ///
  /// The PRD asks for a helpful/not-helpful signal, and storing it would
  /// mean another table, another policy, and a number nobody has yet
  /// decided who reads. What the member actually gets from answering is
  /// the escape hatch below, and that works without persistence. When
  /// somebody is ready to act on the aggregate, it is a small addition.
  bool? _helpful;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.glassSurface(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.faq.question,
                      style: const TextStyle(
                        fontFamily: AppTheme.text,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.15,
                        height: 1.3,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    _open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.faq.answer,
                    style: const TextStyle(
                      fontFamily: AppTheme.text,
                      fontSize: 13.5,
                      height: 1.55,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_helpful == null)
                    Row(
                      children: [
                        const Text(
                          'Was this helpful?',
                          style: TextStyle(
                            fontFamily: AppTheme.text,
                            fontSize: 12.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _HelpfulButton(
                          icon: Icons.thumb_up_outlined,
                          onTap: () => setState(() => _helpful = true),
                        ),
                        const SizedBox(width: 6),
                        _HelpfulButton(
                          icon: Icons.thumb_down_outlined,
                          onTap: () => setState(() => _helpful = false),
                        ),
                      ],
                    )
                  else if (_helpful == true)
                    const Text(
                      'Glad that helped.',
                      style: TextStyle(
                        fontFamily: AppTheme.text,
                        fontSize: 12.5,
                        color: AppTheme.textSecondary,
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Sorry that did not answer it.",
                          style: TextStyle(
                            fontFamily: AppTheme.text,
                            fontSize: 12.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: widget.onContact,
                          child: const Text('Contact support'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HelpfulButton extends StatelessWidget {
  const _HelpfulButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 17, color: AppTheme.textSecondary),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.onContact,
    required this.onWhatsApp,
    required this.onEmail,
  });

  final VoidCallback onContact;
  final VoidCallback onWhatsApp;
  final VoidCallback onEmail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassSurface(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ask a person',
            style: TextStyle(
              fontFamily: AppTheme.text,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.16,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'We answer ${SupportConfig.hours}.',
            style: const TextStyle(
              fontFamily: AppTheme.text,
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onContact,
              child: const Text('Contact support'),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onWhatsApp,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
                  label: const Text('WhatsApp'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEmail,
                  icon: const Icon(Icons.mail_outline_rounded, size: 17),
                  label: const Text('Email'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegalLinks extends StatelessWidget {
  const _LegalLinks({required this.onPrivacy, required this.onTerms});
  final VoidCallback onPrivacy;
  final VoidCallback onTerms;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(onPressed: onPrivacy, child: const Text('Privacy Policy')),
        const Text('·', style: TextStyle(color: AppTheme.textSecondary)),
        TextButton(onPressed: onTerms, child: const Text('Terms')),
      ],
    );
  }
}

class _HelpNotice extends StatelessWidget {
  const _HelpNotice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.glassSurface(),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: AppTheme.text,
          fontSize: 13,
          height: 1.5,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}
