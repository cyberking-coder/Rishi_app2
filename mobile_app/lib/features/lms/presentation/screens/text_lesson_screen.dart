import 'package:flutter/material.dart';

import '../../domain/entities/lesson.dart';

const _kBg = Color(0xFF12082E);
const _kTextSec = Color(0xFFB0A8CC);

/// Renders a text lesson's body.
///
/// The body is stored as markdown, but there's no markdown package in this
/// app and pulling one in for the handful of constructs an admin is likely
/// to use would be more dependency than it's worth. This renders the
/// common subset — headings, bullets, blank-line paragraphs — and shows
/// anything else as plain text, which degrades readably rather than
/// showing raw syntax for unsupported constructs.
class TextLessonScreen extends StatelessWidget {
  final Lesson lesson;

  const TextLessonScreen({super.key, required this.lesson});

  @override
  Widget build(BuildContext context) {
    final blocks = _parse(lesson.bodyMarkdown ?? '');

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios,
                    color: Colors.white, size: 18),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Text(lesson.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: blocks,
            ),
          ),
        ]),
      ),
    );
  }

  List<Widget> _parse(String source) {
    final widgets = <Widget>[];

    for (final rawLine in source.split('\n')) {
      final line = rawLine.trimRight();

      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 12));
        continue;
      }

      if (line.startsWith('### ')) {
        widgets.add(_heading(line.substring(4), 15));
      } else if (line.startsWith('## ')) {
        widgets.add(_heading(line.substring(3), 17));
      } else if (line.startsWith('# ')) {
        widgets.add(_heading(line.substring(2), 20));
      } else if (line.trimLeft().startsWith('- ') ||
          line.trimLeft().startsWith('* ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  ',
                    style: TextStyle(fontSize: 14, color: _kTextSec)),
                Expanded(
                  child: Text(line.trimLeft().substring(2),
                      style: const TextStyle(
                          fontSize: 14, color: _kTextSec, height: 1.6)),
                ),
              ],
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(line,
                style: const TextStyle(
                    fontSize: 14, color: _kTextSec, height: 1.6)),
          ),
        );
      }
    }

    return widgets;
  }

  Widget _heading(String text, double size) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(text,
            style: TextStyle(
                fontSize: size,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.4)),
      );
}
