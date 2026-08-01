import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/certificate.dart';

/// The certificate itself, rendered natively rather than as a PDF.
///
/// The roadmap sketched a generated PDF in a bucket. This draws it in the
/// app and pairs it with a public verification page instead, which is
/// both less machinery and worth more: a PDF is a file anyone can edit in
/// a text editor and re-share, whereas a number that resolves against
/// verify_certificate() can actually be checked by whoever is shown it.
/// Nothing here forecloses adding a PDF export later — the record and its
/// number already exist.
class CertificateScreen extends StatefulWidget {
  final Certificate certificate;

  const CertificateScreen({super.key, required this.certificate});

  @override
  State<CertificateScreen> createState() => _CertificateScreenState();
}

class _CertificateScreenState extends State<CertificateScreen> {
  /// Wraps exactly the certificate — not the surrounding screen — so the
  /// saved image is the credential and nothing else: no app bar, no
  /// buttons, no page background.
  final _certificateKey = GlobalKey();
  bool _saving = false;

  Certificate get certificate => widget.certificate;

  /// Renders the certificate to a PNG and hands it to the system share
  /// sheet, which is also how it gets saved — "Save to Files", "Save to
  /// Photos" and sending it to someone are all the same gesture on both
  /// platforms, so one action covers downloading and sharing.
  Future<void> _saveOrShare() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final boundary = _certificateKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Certificate not ready');

      // Captured at a fixed output width rather than the screen's pixel
      // ratio: a certificate saved on a cheap phone should be the same
      // resolution as one saved on a flagship, and 2000px is enough to
      // print or attach to an email without looking soft.
      final logicalWidth = boundary.size.width;
      final pixelRatio =
          logicalWidth > 0 ? (2000 / logicalWidth).clamp(1.0, 5.0) : 3.0;

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw Exception('Could not render the certificate');

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${certificate.certificateNumber}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());

      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: '${certificate.courseTitle} — certificate '
            '${certificate.certificateNumber}',
        // iPad anchors the share popover to a rect and throws without
        // one. Harmless everywhere else.
        sharePositionOrigin: boundary.localToGlobal(Offset.zero) & boundary.size,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save the certificate: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

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
                  RepaintBoundary(
                    key: _certificateKey,
                    // The admin's own artwork when they've uploaded some,
                    // otherwise the app's drawn design. A course with no
                    // template still issues a presentable certificate.
                    child: certificate.layout != null
                        ? _TemplateCertificate(
                            layout: certificate.layout!,
                            name: certificate.recipientName
                                        ?.trim()
                                        .isNotEmpty ==
                                    true
                                ? certificate.recipientName!
                                : 'Student',
                          )
                        : _CertificateCard(certificate: certificate),
                  ),
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
                  FilledButton.icon(
                    onPressed: _saving ? null : _saveOrShare,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download_rounded, size: 18),
                    label: Text(_saving ? 'Preparing…' : 'Download certificate'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.sage,
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                  const SizedBox(height: 10),
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
              size: 46, color: AppTheme.gold),
          const SizedBox(height: 14),
          const Text(
            'CERTIFICATE OF COMPLETION',
            textAlign: TextAlign.center,
            style: AppTheme.label.copyWith(color: AppTheme.sageDark),
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
            style: AppTheme.displayLarge,
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
            style: AppTheme.headline,
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

/// A soft contrasting outline behind the name, sized relative to the
/// text so it scales with everything else.
List<Shadow> _halo(Color color, double blur) {
  // Rec. 601 luma is enough to decide "is this light or dark", and is
  // cheaper and more predictable here than a full relative-luminance
  // calculation.
  final luma =
      (0.299 * (color.r * 255) + 0.587 * (color.g * 255) + 0.114 * (color.b * 255)) /
          255;
  final halo = luma > 0.6
      ? const Color(0x99000000)
      : const Color(0xB3FFFFFF);

  return [
    Shadow(color: halo, blurRadius: blur),
    Shadow(color: halo, blurRadius: blur * 2),
  ];
}

/// The admin's certificate artwork with the recipient's name printed on
/// it.
///
/// Everything is laid out in fractions of the rendered image, using
/// LayoutBuilder to learn its actual width — the admin positioned the
/// name against a preview of some other size, and only a proportional
/// layout puts it in the same place here. A pixel offset would be right
/// on exactly one screen.
class _TemplateCertificate extends StatelessWidget {
  const _TemplateCertificate({required this.layout, required this.name});

  final CertificateLayout layout;
  final String name;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;

          return Stack(
            children: [
              Image.network(
                layout.templateUrl,
                width: width,
                fit: BoxFit.fitWidth,
                // The certificate is the whole screen here, so a failed
                // image needs to say so rather than collapse to nothing.
                errorBuilder: (_, __, ___) => Container(
                  width: width,
                  padding: const EdgeInsets.all(28),
                  color: AppTheme.surfaceCream,
                  child: const Text(
                    "The certificate artwork couldn't be loaded. Your "
                    'certificate is still valid — the number below is what '
                    'proves it.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return SizedBox(
                    width: width,
                    height: width * 0.7,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.sage,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                },
              ),
              Positioned.fill(
                child: Align(
                  // Alignment runs -1..1, the stored values 0..100.
                  alignment: Alignment(
                    (layout.leftPercent / 50) - 1,
                    (layout.topPercent / 50) - 1,
                  ),
                  child: FractionallySizedBox(
                    widthFactor: 0.84,
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        // Size as a fraction of the image's width, which
                        // is what the admin's slider set it to.
                        fontSize: width * (layout.sizePercent / 100),
                        fontWeight: FontWeight.w600,
                        color: Color(layout.colorValue),
                        height: 1.15,
                        // Certificate artwork is often busy — a starfield,
                        // a photograph, a gradient — and a name with no
                        // separation from it becomes unreadable exactly
                        // where the design is most detailed. The halo is
                        // derived from the chosen colour rather than
                        // configured: dark text gets a light halo and
                        // light text a dark one, so it helps on any
                        // artwork without another setting to get wrong.
                        shadows: _halo(
                          Color(layout.colorValue),
                          width * (layout.sizePercent / 100) * 0.09,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
