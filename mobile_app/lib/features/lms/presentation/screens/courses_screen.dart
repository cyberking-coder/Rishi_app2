import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/widgets/botanical.dart';
import '../../application/lms_providers.dart';
import '../../domain/entities/course_summary.dart';

/// Which slice of the catalog is showing. Purely a client-side view over
/// the same fetched list — the catalog is small enough that filtering
/// server-side would cost a round trip for no benefit.
enum _CourseFilter { all, inProgress, notStarted }

class CoursesScreen extends ConsumerStatefulWidget {
  const CoursesScreen({super.key});

  @override
  ConsumerState<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends ConsumerState<CoursesScreen> {
  _CourseFilter _filter = _CourseFilter.all;

  List<CourseSummary> _apply(List<CourseSummary> courses) {
    switch (_filter) {
      case _CourseFilter.all:
        return courses;
      case _CourseFilter.inProgress:
        return courses.where((c) => c.isStarted).toList();
      case _CourseFilter.notStarted:
        return courses.where((c) => !c.isStarted).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(coursesProvider);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Courses',
                        style: TextStyle(
                          fontFamily: AppTheme.display,
                          fontSize: 30,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Guided programmes, one lesson at a time.',
                        style: TextStyle(
                          fontFamily: AppTheme.text,
                          fontSize: 14.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Clipped to its own box so the sprig can overhang the
                // right edge without widening the row and pushing the
                // title into a wrap.
                SizedBox(
                  width: 76,
                  height: 76,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        right: -34,
                        top: 2,
                        child: LeafSprig(size: 122, angle: -0.42, opacity: 0.6),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          _FilterRow(
            selected: _filter,
            onChanged: (f) => setState(() => _filter = f),
          ),
          const SizedBox(height: 6),

          Expanded(
            child: async.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.sage,
                  strokeWidth: 2,
                ),
              ),
              error: (e, _) => _EmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load courses',
                subtitle: '$e',
              ),
              data: (courses) {
                final visible = _apply(courses);

                if (courses.isEmpty) {
                  return const _EmptyState(
                    icon: Icons.school_outlined,
                    title: 'No courses yet',
                    subtitle:
                        'New programmes will appear here as they are published.',
                  );
                }
                if (visible.isEmpty) {
                  return const _EmptyState(
                    icon: Icons.filter_list_rounded,
                    title: 'Nothing here yet',
                    subtitle: 'Try a different filter.',
                  );
                }

                return RefreshIndicator(
                  color: AppTheme.sage,
                  onRefresh: () async => ref.invalidate(coursesProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (_, i) => CourseCard(course: visible[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final _CourseFilter selected;
  final ValueChanged<_CourseFilter> onChanged;

  const _FilterRow({required this.selected, required this.onChanged});

  static const _labels = {
    _CourseFilter.all: 'All',
    _CourseFilter.inProgress: 'In progress',
    _CourseFilter.notStarted: 'Not started',
  };

  static const _icons = {
    _CourseFilter.all: Icons.eco_outlined,
    _CourseFilter.inProgress: Icons.schedule_rounded,
    _CourseFilter.notStarted: Icons.play_circle_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          for (final entry in _labels.entries) ...[
            Builder(builder: (context) {
              final isSelected = selected == entry.key;
              return GestureDetector(
                onTap: () => onChanged(entry.key),
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 11),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.sage : AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    boxShadow: isSelected ? null : AppTheme.rowShadow,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _icons[entry.key],
                        size: 17,
                        color: isSelected
                            ? AppTheme.textOnSage
                            : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        entry.value,
                        style: TextStyle(
                          fontFamily: AppTheme.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? AppTheme.textOnSage
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppTheme.sageSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: AppTheme.sage),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Catalog card. Also used by the home screen's course row, so it keeps
/// its own layout self-contained rather than depending on page padding.
class CourseCard extends StatelessWidget {
  final CourseSummary course;

  const CourseCard({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // A locked course still opens — the detail screen shows the
        // curriculum with each lesson locked, which is more useful than a
        // dead tap and lets the user see what they'd be unlocking.
        context.push('/course/${course.id}', extra: course.title);
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.clayFill(),
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          boxShadow: AppTheme.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(fit: StackFit.expand, children: [
                _CourseCover(url: course.coverImageUrl),
                // Price is the headline on a locked course; an owned one
                // says so instead, since the number is no longer a
                // decision the user has to make.
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          course.owned
                              ? Icons.check_circle_rounded
                              : course.isFree
                                  ? Icons.lock_open_rounded
                                  : Icons.lock_rounded,
                          size: 12,
                          color: course.owned || course.isFree
                              ? AppTheme.sage
                              : AppTheme.clay,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          course.owned ? 'Enrolled' : course.priceLabel,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: course.owned || course.isFree
                                ? AppTheme.sage
                                : AppTheme.clay,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTheme.text,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      height: 1.25,
                    ),
                  ),
                  if (course.description != null &&
                      course.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      course.description!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTheme.text,
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  // A rule above the meta row, as in the design: it
                  // separates the description from the facts about the
                  // course without needing a second card.
                  const Divider(height: 1, color: AppTheme.border),
                  const SizedBox(height: 14),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.sageSoft,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusPill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_lesson_outlined,
                              size: 15, color: AppTheme.sageDark),
                          const SizedBox(width: 6),
                          Text(
                            '${course.lessonCount} '
                            '${course.lessonCount == 1 ? "lesson" : "lessons"}',
                            style: const TextStyle(
                              fontFamily: AppTheme.text,
                              fontSize: 13,
                              color: AppTheme.sageDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (course.isStarted)
                      Text(
                        '${(course.progressFraction * 100).round()}% complete',
                        style: const TextStyle(
                          fontFamily: AppTheme.text,
                          fontSize: 13,
                          color: AppTheme.sageDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ]),
                  if (course.isStarted) ...[
                    const SizedBox(height: 9),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: course.progressFraction,
                        backgroundColor: AppTheme.sageSoft,
                        valueColor:
                            const AlwaysStoppedAnimation(AppTheme.sage),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cover art with a sage fallback, so a course with no image still looks
/// deliberate rather than broken.
class _CourseCover extends StatelessWidget {
  final String? url;
  const _CourseCover({this.url});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return const _CoverFallback();
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const _CoverFallback(),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const _CoverFallback(),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.sageGradient),
      child: const Center(
        child: Icon(Icons.self_improvement_rounded,
            color: Colors.white38, size: 42),
      ),
    );
  }
}
