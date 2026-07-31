"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import {
  AlertTriangle,
  ChevronDown,
  ChevronUp,
  FileDown,
  FileText,
  Headphones,
  Image as ImageIcon,
  Link as LinkIcon,
  Trash2,
  Video as VideoIcon,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import {
  createModule,
  deleteLesson,
  deleteModule,
  moveLesson,
  moveModule,
} from "@/app/actions/courses";
import { AddLessonDialog } from "./add-lesson-dialog";
import { AddResourceDialog } from "./add-resource-dialog";
import { deleteLessonResource } from "@/app/actions/courses";
import type {
  Audio,
  Course,
  CourseModule,
  LessonResource,
  LessonType,
  LessonWithMedia,
  ResourceType,
  Video,
} from "@/lib/types";

interface ModuleWithLessons extends CourseModule {
  lessons: LessonWithMedia[];
}

const LESSON_ICON: Record<LessonType, typeof Headphones> = {
  audio: Headphones,
  video: VideoIcon,
  text: FileText,
};

const RESOURCE_ICON: Record<ResourceType, typeof Headphones> = {
  pdf: FileText,
  image: ImageIcon,
  file: FileDown,
  link: LinkIcon,
};

export function CourseBuilder({
  course,
  modules,
  audioLibrary,
  videoLibrary,
}: {
  course: Course;
  modules: ModuleWithLessons[];
  audioLibrary: Audio[];
  videoLibrary: Video[];
}) {
  const router = useRouter();
  const [newModuleTitle, setNewModuleTitle] = useState("");
  const [busy, setBusy] = useState(false);

  async function run(fn: () => Promise<{ ok: boolean; error?: string }>, ok: string) {
    setBusy(true);
    try {
      const result = await fn();
      if (!result.ok) return toast.error(result.error ?? "Something went wrong");
      toast.success(ok);
      router.refresh();
    } finally {
      setBusy(false);
    }
  }

  async function onAddModule(e: React.FormEvent) {
    e.preventDefault();
    if (!newModuleTitle.trim()) return;
    await run(
      () => createModule({ courseId: course.id, title: newModuleTitle.trim() }),
      "Module added",
    );
    setNewModuleTitle("");
  }

  return (
    <div className="space-y-4">
      {modules.length === 0 && (
        <Card>
          <CardContent className="py-8 text-center text-sm text-muted-foreground">
            No modules yet. Add one below to start building this course.
          </CardContent>
        </Card>
      )}

      {modules.map((module, moduleIndex) => (
        <Card key={module.id}>
          <CardContent className="p-4">
            <div className="flex items-start justify-between gap-3">
              <div>
                <p className="font-medium">{module.title}</p>
                <p className="text-xs text-muted-foreground">
                  {module.lessons.length}{" "}
                  {module.lessons.length === 1 ? "lesson" : "lessons"}
                </p>
              </div>

              <div className="flex items-center gap-1">
                <Button
                  variant="ghost"
                  size="icon"
                  disabled={busy || moduleIndex === 0}
                  onClick={() =>
                    run(
                      () =>
                        moveModule({
                          moduleId: module.id,
                          courseId: course.id,
                          direction: "up",
                        }),
                      "Moved",
                    )
                  }
                >
                  <ChevronUp className="h-4 w-4" />
                </Button>
                <Button
                  variant="ghost"
                  size="icon"
                  disabled={busy || moduleIndex === modules.length - 1}
                  onClick={() =>
                    run(
                      () =>
                        moveModule({
                          moduleId: module.id,
                          courseId: course.id,
                          direction: "down",
                        }),
                      "Moved",
                    )
                  }
                >
                  <ChevronDown className="h-4 w-4" />
                </Button>
                <Button
                  variant="ghost"
                  size="icon"
                  className="text-destructive"
                  disabled={busy}
                  onClick={() => {
                    if (
                      !confirm(
                        `Delete "${module.title}" and its ${module.lessons.length} lesson(s)?`,
                      )
                    ) {
                      return;
                    }
                    run(
                      () =>
                        deleteModule({
                          moduleId: module.id,
                          courseId: course.id,
                        }),
                      "Module deleted",
                    );
                  }}
                >
                  <Trash2 className="h-4 w-4" />
                </Button>
              </div>
            </div>

            <div className="mt-3 space-y-2">
              {module.lessons.map((lesson, lessonIndex) => {
                const Icon = LESSON_ICON[lesson.lesson_type];
                const media = lesson.audios ?? lesson.videos;
                // Playback is authorized against the media row's own
                // is_premium, not the course's — so a mismatch means the
                // lesson won't gate the way the course implies.
                const mismatched =
                  media != null && media.is_premium !== course.is_premium;

                return (
                  <div
                    key={lesson.id}
                    className="rounded-md border border-border/60"
                  >
                  <div className="flex items-center gap-3 px-3 py-2">
                    <Icon className="h-4 w-4 shrink-0 text-muted-foreground" />

                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm">{lesson.title}</p>
                      <p className="truncate text-xs text-muted-foreground">
                        {lesson.lesson_type === "text"
                          ? "Text lesson"
                          : media
                            ? media.title
                            : "Media unavailable — it may have been deleted"}
                      </p>
                    </div>

                    {mismatched && (
                      <Badge
                        variant="warning"
                        className="shrink-0 gap-1"
                        title={
                          course.is_premium
                            ? "This course is premium but the attached media is marked free, so it will play for free users. Fix it from the Audios tab."
                            : "This course is free but the attached media is marked premium, so free users won't be able to play it. Fix it from the Audios tab."
                        }
                      >
                        <AlertTriangle className="h-3 w-3" />
                        {media?.is_premium ? "Media premium" : "Media free"}
                      </Badge>
                    )}

                    <div className="flex shrink-0 items-center gap-1">
                      <AddResourceDialog
                        lessonId={lesson.id}
                        courseId={course.id}
                      />
                      <Button
                        variant="ghost"
                        size="icon"
                        disabled={busy || lessonIndex === 0}
                        onClick={() =>
                          run(
                            () =>
                              moveLesson({
                                lessonId: lesson.id,
                                moduleId: module.id,
                                courseId: course.id,
                                direction: "up",
                              }),
                            "Moved",
                          )
                        }
                      >
                        <ChevronUp className="h-4 w-4" />
                      </Button>
                      <Button
                        variant="ghost"
                        size="icon"
                        disabled={busy || lessonIndex === module.lessons.length - 1}
                        onClick={() =>
                          run(
                            () =>
                              moveLesson({
                                lessonId: lesson.id,
                                moduleId: module.id,
                                courseId: course.id,
                                direction: "down",
                              }),
                            "Moved",
                          )
                        }
                      >
                        <ChevronDown className="h-4 w-4" />
                      </Button>
                      <Button
                        variant="ghost"
                        size="icon"
                        className="text-destructive"
                        disabled={busy}
                        onClick={() =>
                          run(
                            () =>
                              deleteLesson({
                                lessonId: lesson.id,
                                courseId: course.id,
                              }),
                            "Lesson removed",
                          )
                        }
                      >
                        <Trash2 className="h-4 w-4" />
                      </Button>
                    </div>
                  </div>

                  {(lesson.lesson_resources ?? []).length > 0 && (
                    <div className="space-y-1 border-t border-border/60 bg-muted/30 px-3 py-2">
                      {(lesson.lesson_resources ?? []).map((r) => {
                        const ResIcon = RESOURCE_ICON[r.resource_type];
                        return (
                          <div
                            key={r.id}
                            className="flex items-center gap-2 text-xs"
                          >
                            <ResIcon className="h-3.5 w-3.5 shrink-0 text-muted-foreground" />
                            <a
                              href={r.url}
                              target="_blank"
                              rel="noreferrer"
                              className="min-w-0 flex-1 truncate hover:underline"
                            >
                              {r.title}
                            </a>
                            <Button
                              variant="ghost"
                              size="icon"
                              className="h-6 w-6 text-destructive"
                              disabled={busy}
                              onClick={() =>
                                run(
                                  () =>
                                    deleteLessonResource({
                                      resourceId: r.id,
                                      courseId: course.id,
                                    }),
                                  "Resource removed",
                                )
                              }
                            >
                              <Trash2 className="h-3 w-3" />
                            </Button>
                          </div>
                        );
                      })}
                    </div>
                  )}
                  </div>
                );
              })}

              <AddLessonDialog
                courseId={course.id}
                moduleId={module.id}
                coursePremium={course.is_premium}
                audioLibrary={audioLibrary}
                videoLibrary={videoLibrary}
              />
            </div>
          </CardContent>
        </Card>
      ))}

      <Card>
        <CardContent className="p-4">
          <form onSubmit={onAddModule} className="flex items-center gap-2">
            <Input
              value={newModuleTitle}
              onChange={(e) => setNewModuleTitle(e.target.value)}
              placeholder="New module title (e.g. Week 1 — Getting Started)"
              disabled={busy}
            />
            <Button type="submit" disabled={busy || !newModuleTitle.trim()}>
              Add module
            </Button>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
