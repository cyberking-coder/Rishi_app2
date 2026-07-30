"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { ImagePlus, Lock, Unlock } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { NativeOption, NativeSelect } from "@/components/ui/native-select";
import {
  createCourse,
  updateCourse,
  uploadCourseCover,
} from "@/app/actions/courses";
import type { Category, Course } from "@/lib/types";

function fileToBase64(f: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      const result = reader.result as string;
      resolve(result.split(",")[1] ?? "");
    };
    reader.onerror = () => reject(new Error("Could not read image"));
    reader.readAsDataURL(f);
  });
}

/** Shared create/edit form for a course's own details (not its modules
 *  or lessons — that stays in the builder below it). Shows a live phone
 *  mockup next to the form so a non-technical admin can see exactly what
 *  they're publishing before they hit save. */
export function CourseFormDialog({
  categories,
  course,
  trigger,
}: {
  categories: Category[];
  /** Omit for "create new course"; pass the existing course to edit it. */
  course?: Course;
  /** Custom trigger element. Defaults to a "New course" button. */
  trigger?: React.ReactNode;
}) {
  const router = useRouter();
  const isEdit = !!course;
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);

  const [title, setTitle] = useState(course?.title ?? "");
  const [description, setDescription] = useState(course?.description ?? "");
  const [categoryId, setCategoryId] = useState(course?.category_id ?? "");
  const [isPremium, setIsPremium] = useState(course?.is_premium ?? true);
  const [coverFile, setCoverFile] = useState<File | null>(null);
  const [coverPreviewUrl, setCoverPreviewUrl] = useState<string | null>(
    course?.cover_image_url ?? null,
  );

  function reset() {
    setTitle(course?.title ?? "");
    setDescription(course?.description ?? "");
    setCategoryId(course?.category_id ?? "");
    setIsPremium(course?.is_premium ?? true);
    setCoverFile(null);
    setCoverPreviewUrl(course?.cover_image_url ?? null);
  }

  function onCoverPicked(f: File | null) {
    setCoverFile(f);
    setCoverPreviewUrl(f ? URL.createObjectURL(f) : (course?.cover_image_url ?? null));
  }

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!title.trim()) return toast.error("Give the course a title");

    setBusy(true);
    try {
      let courseId = course?.id;

      if (isEdit) {
        const result = await updateCourse({
          courseId: course!.id,
          title: title.trim(),
          description: description.trim() || null,
          categoryId: categoryId || null,
          isPremium,
        });
        if (!result.ok) throw new Error(result.error);
      } else {
        const result = await createCourse({
          title: title.trim(),
          description: description.trim() || undefined,
          isPremium,
          categoryId: categoryId || undefined,
        });
        if (!result.ok) throw new Error(result.error);
        courseId = result.id;
      }

      if (coverFile && courseId) {
        const base64 = await fileToBase64(coverFile);
        const coverResult = await uploadCourseCover({
          courseId,
          fileName: coverFile.name,
          contentType: coverFile.type || "image/jpeg",
          base64,
        });
        // Non-fatal: the course itself saved fine either way.
        if (!coverResult.ok) toast.error(`Cover image failed: ${coverResult.error}`);
      }

      toast.success(isEdit ? "Course updated" : "Course created");
      setOpen(false);

      if (isEdit) {
        router.refresh();
      } else {
        reset();
        // Straight into the builder — a course with no modules isn't
        // useful, so the next step is always "add content".
        router.push(`/courses/${courseId}`);
      }
    } catch (err) {
      toast.error(
        err instanceof Error ? err.message : "Could not save course",
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <Dialog
      open={open}
      onOpenChange={(o) => {
        if (busy) return;
        if (!o) reset();
        setOpen(o);
      }}
    >
      <DialogTrigger asChild>
        {trigger ?? <Button>New course</Button>}
      </DialogTrigger>

      <DialogContent className="max-w-3xl">
        <DialogHeader>
          <DialogTitle>{isEdit ? "Edit course details" : "New course"}</DialogTitle>
        </DialogHeader>

        <form onSubmit={onSubmit} className="grid gap-6 sm:grid-cols-[1fr_260px]">
          <div className="space-y-4">
            <div>
              <Label htmlFor="cf-title">Title</Label>
              <Input
                id="cf-title"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="e.g. Foundations of Meditation"
                disabled={busy}
              />
            </div>

            <div>
              <Label htmlFor="cf-cover">Cover image</Label>
              <Input
                id="cf-cover"
                type="file"
                accept="image/*"
                disabled={busy}
                onChange={(e) => onCoverPicked(e.target.files?.[0] ?? null)}
              />
              <p className="mt-1 text-xs text-muted-foreground">
                Shown on the course card in the app. Landscape images look
                best.
              </p>
            </div>

            <div>
              <Label htmlFor="cf-desc">Description</Label>
              <Textarea
                id="cf-desc"
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                rows={4}
                disabled={busy}
              />
            </div>

            <div>
              <Label htmlFor="cf-category">Category</Label>
              <NativeSelect
                id="cf-category"
                value={categoryId}
                onChange={(e) => setCategoryId(e.target.value)}
                disabled={busy}
              >
                <NativeOption value="">No category</NativeOption>
                {categories.map((c) => (
                  <NativeOption key={c.id} value={c.id}>
                    {c.name}
                  </NativeOption>
                ))}
              </NativeSelect>
            </div>

            <div className="flex items-center gap-2">
              <input
                id="cf-premium"
                type="checkbox"
                checked={isPremium}
                onChange={(e) => setIsPremium(e.target.checked)}
                disabled={busy}
                className="h-4 w-4 accent-primary"
              />
              <Label htmlFor="cf-premium">Premium course</Label>
            </div>

            {!isEdit && (
              <p className="text-xs text-muted-foreground">
                Courses start as a draft — they stay hidden in the app until
                you publish them.
              </p>
            )}
          </div>

          {/* Live preview — mirrors the course card + detail header a
              member sees in the mobile app, so a non-technical admin can
              tell what they're publishing without opening the app. */}
          <div className="flex flex-col items-center gap-2">
            <div className="w-full max-w-[220px] overflow-hidden rounded-[1.75rem] border-8 border-foreground/90 bg-background shadow-lg">
              <div className="flex aspect-[9/16] flex-col bg-muted/40">
                <div className="relative aspect-video w-full shrink-0 bg-muted">
                  {coverPreviewUrl ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={coverPreviewUrl}
                      alt=""
                      className="h-full w-full object-cover"
                    />
                  ) : (
                    <div className="flex h-full w-full flex-col items-center justify-center gap-1 text-muted-foreground">
                      <ImagePlus className="h-5 w-5" />
                      <span className="text-[10px]">No cover yet</span>
                    </div>
                  )}
                  <span className="absolute right-1.5 top-1.5 inline-flex items-center gap-1 rounded-full bg-background/90 px-1.5 py-0.5 text-[9px] font-medium">
                    {isPremium ? (
                      <Lock className="h-2.5 w-2.5" />
                    ) : (
                      <Unlock className="h-2.5 w-2.5" />
                    )}
                    {isPremium ? "Premium" : "Free"}
                  </span>
                </div>
                <div className="flex-1 space-y-1.5 overflow-hidden p-2.5">
                  <p className="line-clamp-2 text-xs font-semibold leading-snug">
                    {title.trim() || "Course title"}
                  </p>
                  <p className="line-clamp-4 text-[10px] leading-snug text-muted-foreground">
                    {description.trim() || "Course description will appear here."}
                  </p>
                </div>
              </div>
            </div>
            <p className="text-center text-[11px] text-muted-foreground">
              Preview
            </p>
          </div>

          <DialogFooter className="sm:col-span-2">
            <Button
              type="button"
              variant="outline"
              onClick={() => setOpen(false)}
              disabled={busy}
            >
              Cancel
            </Button>
            <Button type="submit" disabled={busy}>
              {busy ? "Saving…" : isEdit ? "Save" : "Create"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
