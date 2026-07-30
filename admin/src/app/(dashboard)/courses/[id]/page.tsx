import Link from "next/link";
import { notFound } from "next/navigation";
import { ChevronLeft } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { PageHeader } from "@/components/page-header";
import { CourseBuilder } from "@/components/courses/course-builder";
import { Badge } from "@/components/ui/badge";
import type {
  Audio,
  Course,
  CourseModule,
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

  const [{ data: modules }, { data: audios }, { data: videos }] = await Promise.all([
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
  ]);

  // Lessons come back nested but unordered; sort them here so the builder
  // component stays presentational.
  const orderedModules = (modules ?? []).map((m) => ({
    ...m,
    lessons: [...(m.lessons ?? [])].sort((a, b) => a.position - b.position),
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
          </div>
        }
      />

      <CourseBuilder
        course={course}
        modules={orderedModules}
        audioLibrary={audios ?? []}
        videoLibrary={videos ?? []}
      />
    </div>
  );
}
