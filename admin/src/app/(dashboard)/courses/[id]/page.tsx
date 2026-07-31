import Link from "next/link";
import { notFound } from "next/navigation";
import { ChevronLeft } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { PageHeader } from "@/components/page-header";
import { CourseBuilder } from "@/components/courses/course-builder";
import { CourseFormDialog } from "@/components/courses/course-form-dialog";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import type {
  Audio,
  Category,
  Course,
  CourseModule,
  LessonResource,
  LessonWithMedia,
  Video,
} from "@/lib/types";

export const dynamic = "force-dynamic";

interface ModuleWithLessons extends CourseModule {
  lessons: LessonWithMedia[];
}

export default async function CourseBuilderPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = createClient();

  const { data: course } = await supabase
    .from("courses")
    .select("*")
    .eq("id", id)
    .maybeSingle<Course>();

  if (!course) notFound();

  const [
    { data: modules, error: modulesError },
    { data: audios },
    { data: videos },
    { data: categories },
    { data: assets },
  ] = await Promise.all([
      // lesson_resources is fetched separately rather than embedded here.
      // A single failing embed takes the WHOLE select down, which showed
      // up as "no modules yet" on a course that plainly had modules —
      // the module list must not depend on an optional child table.
      supabase
        .from("course_modules")
        .select(
          "*, lessons(*, audios(id, title, is_premium), videos(id, title, is_premium))",
        )
        .eq("course_id", id)
        .order("position", { ascending: true })
        .returns<ModuleWithLessons[]>(),
      // The library the builder picks lesson media from. Only published
      // audio can be attached — attaching a draft would produce a lesson
      // that silently fails at playback, since the license functions
      // require status = 'published'.
      supabase
        .from("audios")
        .select("*")
        .eq("status", "published")
        .order("created_at", { ascending: false })
        .returns<Audio[]>(),
      supabase
        .from("videos")
        .select("*")
        .eq("status", "published")
        .order("created_at", { ascending: false })
        .returns<Video[]>(),
      supabase
        .from("categories")
        .select("*")
        .order("name", { ascending: true })
        .returns<Category[]>(),
      // content_assets is polymorphic (no FK to videos), so this can't be
      // an embedded join — fetch the ready asset ids and intersect below.
      supabase
        .from("content_assets")
        .select("content_id")
        .eq("content_type", "video")
        .eq("status", "ready")
        .returns<{ content_id: string }[]>(),
    ]);

  // Attach resources to their lessons. A failure here degrades to
  // "no resources shown" rather than an empty curriculum.
  const lessonIds = (modules ?? []).flatMap((m) =>
    (m.lessons ?? []).map((l) => l.id),
  );
  const { data: resources } = lessonIds.length
    ? await supabase
        .from("lesson_resources")
        .select("*")
        .in("lesson_id", lessonIds)
        .order("position", { ascending: true })
        .returns<LessonResource[]>()
    : { data: [] as LessonResource[] };

  const resourcesByLesson = new Map<string, LessonResource[]>();
  for (const r of resources ?? []) {
    const list = resourcesByLesson.get(r.lesson_id) ?? [];
    list.push(r);
    resourcesByLesson.set(r.lesson_id, list);
  }

  // A video with neither a Bunny id nor a ready R2 asset has no media
  // behind it — attaching it produces a lesson that 404s the moment
  // someone taps it. Keep those out of the picker entirely.
  const withAsset = new Set((assets ?? []).map((a) => a.content_id));
  const playableVideos = (videos ?? []).filter(
    (v) => v.bunny_video_id !== null || withAsset.has(v.id),
  );

  // Lessons come back nested but unordered; sort them here so the builder
  // component stays presentational.
  const orderedModules = (modules ?? []).map((m) => ({
    ...m,
    lessons: [...(m.lessons ?? [])]
      .sort((a, b) => a.position - b.position)
      .map((l) => ({ ...l, lesson_resources: resourcesByLesson.get(l.id) ?? [] })),
  }));

  return (
    <div>
      <Link
        href="/courses"
        className="mb-4 inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground"
      >
        <ChevronLeft className="h-4 w-4" />
        All courses
      </Link>

      <PageHeader
        title={course.title}
        description={course.description ?? undefined}
        action={
          <div className="flex items-center gap-2">
            <Badge variant={course.is_premium ? "default" : "outline"}>
              {course.is_premium ? "Premium" : "Free"}
            </Badge>
            <Badge
              variant={course.status === "published" ? "success" : "outline"}
            >
              {course.status}
            </Badge>
            <CourseFormDialog
              categories={categories ?? []}
              course={course}
              trigger={<Button variant="outline" size="sm">Edit details</Button>}
            />
          </div>
        }
      />

      {modulesError && (
        <div className="mb-4 rounded-lg border border-destructive/40 bg-destructive/10 p-4 text-sm text-destructive">
          Could not load this course&apos;s modules: {modulesError.message}
        </div>
      )}

      <CourseBuilder
        course={course}
        modules={orderedModules}
        audioLibrary={audios ?? []}
        videoLibrary={playableVideos}
      />
    </div>
  );
}
