import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/config/purchase_config.dart';
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
          // Title and a search affordance, no strapline. The design
          // gives every tab a bare one-word heading; the sentence that
          // was here explained the tab to somebody already looking at
          // it, and pushed the first card off the fold.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 12, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    kEducationFramingEnabled ? 'Courses' : 'Videos',
                    style: AppTheme.displayLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => context.push('/search'),
                  icon: const Icon(Icons.search_rounded,
                      size: 21, color: AppTheme.sageDark),
                ),
              ],
            ),
          ),

          _FilterRow(
            selected: _filter,
            onChanged: (f) => setState(() => _filter = f),
          ),
          const SizedBox(height: 10),

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
                title: 'Could not load this',
                subtitle: '$e',
              ),
              data: (courses) {
                final visible = _apply(courses);

                if (courses.isEmpty) {
                  return _EmptyState(
                    icon: kEducationFramingEnabled
                        ? Icons.school_outlined
                        : Icons.video_library_outlined,
                    title: kEducationFramingEnabled
                        ? 'No courses yet'
                        : 'Nothing here yet',
                    subtitle:
                        'New releases will appear here as they are published.',
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

  @override
  Widget build(BuildContext context) {
    // A segmented control, not a scrolling row of pills. There are
    // exactly three mutually exclusive views and they all fit — pills
    // implied a list that might continue past the right edge, and a
    // filled violet pill made the current filter look like the primary
    // action on the screen.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: const Color(0x121E1830),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            for (final entry in _labels.entries)
              Expanded(
                child: GestureDetector(
                  // Opaque so a tap anywhere in the segment counts, not
                  // only on the glyphs of the label itself.
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(entry.key),
                  child: Container(
                    height: 30,
                    alignment: Alignment.center,
                    decoration: selected == entry.key
                        ? BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(7),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1F1E1830),
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ],
                          )
                        : null,
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        fontFamily: AppTheme.text,
                        fontSize: 13,
                        fontWeight: selected == entry.key
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: selected == entry.key
                            ? AppTheme.textPrimary
                            : const Color(0xFF544A6E),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
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

/// Catalog card. Keeps its own layout self-contained rather than
/// depending on page padding, so it can be dropped into any list.
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
        decoration: AppTheme.glassSurface(radius: AppTheme.radiusCard),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 176,
              width: double.infinity,
              child: _CourseCover(url: course.coverImageUrl),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              course.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: AppTheme.text,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.4,
                                color: AppTheme.textPrimary,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${course.lessonCount} '
                              '${course.lessonCount == 1 ? kPartWord : "${kPartWord}s"}',
                              style: const TextStyle(
                                fontFamily: AppTheme.text,
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Moved off the cover art and onto the card body.
                      // A white pill floating over a photograph had to
                      // fight whatever was behind it; here the chip has
                      // a surface of its own and can be quiet.
                      _StatusChip(course: course),
                    ],
                  ),
                  if (course.description != null &&
                      course.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      course.description!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTheme.text,
                        fontSize: 15,
                        color: Color(0xFF544A6E),
                        height: 1.5,
                      ),
                    ),
                  ],
                  if (course.isStarted) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: course.progressFraction,
                        backgroundColor: AppTheme.well,
                        valueColor: const AlwaysStoppedAnimation(AppTheme.sage),
                        minHeight: 3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          course.completedLessonCount >= course.lessonCount
                              ? 'Completed'
                              : 'In progress',
                          style: const TextStyle(
                            fontFamily: AppTheme.text,
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        Text(
                          '${(course.progressFraction * 100).round()}%',
                          style: const TextStyle(
                            fontFamily: AppTheme.text,
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
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

/// Owned, free, priced, or locked — in one chip.
///
/// Price is the headline on a course somebody might buy; an owned one
/// says so instead, because the number is no longer a decision they
/// have to make. On iOS, where no purchase can be offered in the app,
/// a priced course reads "Locked" rather than showing a figure the app
/// has no way to charge.
class _StatusChip extends StatelessWidget {
  final CourseSummary course;

  const _StatusChip({required this.course});

  @override
  Widget build(BuildContext context) {
    final positive = course.owned || course.isFree;
    final label = course.owned
        ? (kEducationFramingEnabled ? 'Enrolled' : 'Yours')
        : kPurchaseUiEnabled || course.isFree
            ? course.priceLabel
            : 'Locked';

    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: positive ? AppTheme.sageSoft : AppTheme.well,
        borderRadius: BorderRadius.circular(12),
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
            size: 13,
            color: positive ? const Color(0xFF4C1D95) : AppTheme.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.text,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color:
                  positive ? const Color(0xFF4C1D95) : AppTheme.textSecondary,
            ),
          ),
        ],
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
