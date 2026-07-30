import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../access/application/access_providers.dart';
import '../../../home/presentation/widgets/premium_lock.dart';
import '../../application/lms_providers.dart';
import '../../domain/entities/course_summary.dart';

const _kBg = Color(0xFF12082E);
const _kSurface = Color(0xFF1C1040);
const _kAccent = Color(0xFF8B5CF6);
const _kTextSec = Color(0xFFB0A8CC);

class CoursesScreen extends ConsumerWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(coursesProvider);
    final access = ref.watch(accessStateProvider).valueOrNull;

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
              const Expanded(
                child: Text('Courses',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
            ]),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: _kAccent, strokeWidth: 2)),
              error: (e, _) => Center(
                child: Text('Could not load courses.\n$e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _kTextSec)),
              ),
              data: (courses) {
                if (courses.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No courses yet.\nCheck back soon.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _kTextSec),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: courses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => CourseCard(
                    course: courses[i],
                    locked: courses[i].isPremium && access?.hasAccess != true,
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class CourseCard extends ConsumerWidget {
  final CourseSummary course;
  final bool locked;

  const CourseCard({super.key, required this.course, required this.locked});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        // A locked course still opens — the detail screen shows the
        // curriculum with each lesson locked, which is more useful than a
        // dead tap and lets the user see what they'd be unlocking.
        context.push('/course/${course.id}', extra: course.title);
      },
      child: Container(
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 120,
              width: double.infinity,
              child: Stack(fit: StackFit.expand, children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: course.coverImageUrl != null
                      ? Image.network(course.coverImageUrl!, fit: BoxFit.cover)
                      : Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF6D28D9), Color(0xFF4C1D95)],
                            ),
                          ),
                          child: const Icon(Icons.school_outlined,
                              color: Colors.white54, size: 40),
                        ),
                ),
                if (locked) const PremiumLockBadge(),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  if (course.description != null) ...[
                    const SizedBox(height: 4),
                    Text(course.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: _kTextSec, height: 1.4)),
                  ],
                  const SizedBox(height: 10),
                  Row(children: [
                    Text(
                      '${course.lessonCount} '
                      '${course.lessonCount == 1 ? "lesson" : "lessons"}',
                      style: const TextStyle(fontSize: 11, color: _kTextSec),
                    ),
                    if (course.isStarted) ...[
                      const Text(' · ',
                          style: TextStyle(fontSize: 11, color: _kTextSec)),
                      Text(
                        '${course.completedLessonCount} done',
                        style: const TextStyle(fontSize: 11, color: _kAccent),
                      ),
                    ],
                  ]),
                  if (course.isStarted) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: course.progressFraction,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation(_kAccent),
                        minHeight: 3,
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
