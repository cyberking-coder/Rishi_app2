"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
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
import { createCourse } from "@/app/actions/courses";
import type { Category } from "@/lib/types";

export function CreateCourseDialog({ categories }: { categories: Category[] }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);

  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [categoryId, setCategoryId] = useState("");
  const [isPremium, setIsPremium] = useState(true);

  function reset() {
    setTitle("");
    setDescription("");
    setCategoryId("");
    setIsPremium(true);
  }

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!title.trim()) return toast.error("Give the course a title");

    setBusy(true);
    try {
      const result = await createCourse({
        title: title.trim(),
        description: description.trim() || undefined,
        isPremium,
        categoryId: categoryId || undefined,
      });
      if (!result.ok) throw new Error(result.error);

      toast.success("Course created");
      setOpen(false);
      reset();
      // Straight into the builder — a course with no modules isn't useful,
      // so the next step is always "add content".
      router.push(`/courses/${result.id}`);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Could not create course");
    } finally {
      setBusy(false);
    }
  }

  return (
    <Dialog
      open={open}
      onOpenChange={(o) => {
        if (!busy) setOpen(o);
      }}
    >
      <DialogTrigger asChild>
        <Button>New course</Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>New course</DialogTitle>
        </DialogHeader>

        <form onSubmit={onSubmit} className="space-y-4">
          <div>
            <Label htmlFor="cc-title">Title</Label>
            <Input
              id="cc-title"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="e.g. Foundations of Meditation"
              disabled={busy}
            />
          </div>

          <div>
            <Label htmlFor="cc-desc">Description</Label>
            <Textarea
              id="cc-desc"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              rows={3}
              disabled={busy}
            />
          </div>

          <div>
            <Label htmlFor="cc-category">Category</Label>
            <NativeSelect
              id="cc-category"
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
              id="cc-premium"
              type="checkbox"
              checked={isPremium}
              onChange={(e) => setIsPremium(e.target.checked)}
              disabled={busy}
              className="h-4 w-4 accent-primary"
            />
            <Label htmlFor="cc-premium">Premium course</Label>
          </div>

          <p className="text-xs text-muted-foreground">
            Courses start as a draft — they stay hidden in the app until you
            publish them.
          </p>

          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => setOpen(false)}
              disabled={busy}
            >
              Cancel
            </Button>
            <Button type="submit" disabled={busy}>
              {busy ? "Creating…" : "Create"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
