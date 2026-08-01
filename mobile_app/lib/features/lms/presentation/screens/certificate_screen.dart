import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/quiz.dart';

/// The certificate itself, rendered natively rather than as a PDF.
///
/// The roadmap sketched a generated PDF in a bucket. This draws it in the
/// app and pairs it with a public verification page instead, which is
/// both less machinery and worth more: a PDF is a file anyone can edit in
/// a text editor and re-share, whereas a number that resolves against
/// verify_certificate() can actually be checked by whoever is shown it.
/// Nothing here forecloses adding a PDF export later — the record and its
/// number already exist.
class CertificateScreen extends StatelessWidget {
  final Certificate certificate;

  const CertificateScreen({super.key, required this.certificate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Text(
                      'Certificate',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  _CertificateCard(certificate: certificate),
                  const SizedBox(height: 20),
                  if (!certificate.isValid)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'This certificate has been withdrawn and will not '
                        'verify.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.clay, fontSize: 13),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: certificate.certificateNumber),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Certificate number copied'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy certificate number'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: AppTheme.textPrimary,
                      side: const BorderSide(color: AppTheme.border),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Anyone can confirm this certificate from its number. '
                    'It stays valid for life.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CertificateCard extends StatelessWidget {
  const _CertificateCard({required this.certificate});

  final Certificate certificate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.sage, width: 1.5),
      ),
      child: Column(
        children: [
          const Icon(Icons.workspace_premium_rounded,
              size: 46, color: AppTheme.sage),
          const SizedBox(height: 14),
          const Text(
            'CERTIFICATE OF COMPLETION',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: AppTheme.sage,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'This is to certify that',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            certificate.recipientName?.trim().isNotEmpty == true
                ? certificate.recipientName!
                : 'Student',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'has successfully completed',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            certificate.courseTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 24),
          Container(height: 1, color: AppTheme.border),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Meta(
                label: 'Issued',
                value: _formatDate(certificate.issuedAt),
              ),
              _Meta(
                label: 'Certificate no.',
                value: certificate.certificateNumber,
                alignEnd: true,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Know Thyself · Anurag Rishi',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _Meta extends StatelessWidget {
  const _Meta({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
