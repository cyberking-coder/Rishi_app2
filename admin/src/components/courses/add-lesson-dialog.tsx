"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Plus } from "lucide-react";
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
import { createLesson } from "@/app/actions/courses";
import type { Audio, LessonType } from "@/lib/types";

export function AddLessonDialog({
  courseId,
  moduleId,
  audioLibrary,
}: {
  courseId: string;
  moduleId: string;
  audioLibrary: Audio[];
}) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);

  const [title, setTitle] = useState("");
  const [lessonType, setLessonType] = useState<LessonType>("audio");
  const [audioId, setAudioId] = useState("");
  const [bodyMarkdown, setBodyMarkdown] = useState("");

  function reset() {
    setTitle("");
    setLessonType("audio");
    setAudioId("");
    setBodyMarkdown("");
  }

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!title.trim()) return toast.error("Give the lesson a title");

    setBusy(true);
    try {
      const result = await createLesson({
        moduleId,
        courseId,
        title: title.trim(),
        lessonType,
        audioId: lessonType === "audio" ? audioId : undefined,
        bodyMarkdown: lessonType === "text" ? bodyMarkdown : undefined,
      });
      if (!result.ok) throw new Error(result.error);

      toast.success("Lesson added");
      setOpen(false);
      reset();
      router.refresh();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Could not add lesson");
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
        <Button variant="outline" size="sm" className="w-full gap-1">
          <Plus className="h-4 w-4" />
          Add lesson
        </Button>
      </DialogTrigger>

      <DialogContent>
        <DialogHeader>
          <DialogTitle>Add lesson</DialogTitle>
        </DialogHeader>

        <form onSubmit={onSubmit} className="space-y-4">
          <div>
            <Label htmlFor="al-title">Title</Label>
            <Input
              id="al-title"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="e.g. Sitting posture"
              disabled={busy}
            />
          </div>

          <div>
            <Label htmlFor="al-type">Type</Label>
            <select
              id="al-type"
              value={lessonType}
              onChange={(e) => setLessonType(e.target.value as LessonType)}
              disabled={busy}
              className="flex h-9 w-full rounded-md border border-input bg-transparent px-3 py-1 text-sm shadow-sm focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:cursor-not-allowed disabled:opacity-50"
            >
              <option value="audio">Audio</option>
              <option value="text">Text</option>
            </select>
          </div>

          {lessonType === "audio" && (
            <div>
              <Label htmlFor="al-audio">Audio</Label>
              <select
                id="al-audio"
                value={audioId}
                onChange={(e) => setAudioId(e.target.value)}
                disabled={busy}
                className="flex h-9 w-full rounded-md border border-input bg-transparent px-3 py-1 text-sm shadow-sm focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:cursor-not-allowed disabled:opacity-50"
              >
                <option value="">Select from your library…</option>
                {audioLibrary.map((a) => (
                  <option key={a.id} value={a.id}>
                    {a.title}
                    {a.is_premium ? " (premium)" : " (free)"}
                  </option>
                ))}
              </select>
              <p className="mt-1 text-xs text-muted-foreground">
                {audioLibrary.length === 0
                  ? "No published audio yet — upload one in the Audios tab first."
                  : "Only published audio is listed. To add something new, upload it in the Audios tab, then attach it here."}
              </p>
            </div>
          )}

          {lessonType === "text" && (
            <div>
              <Label htmlFor="al-body">Content</Label>
              <Textarea
                id="al-body"
                value={bodyMarkdown}
                onChange={(e) => setBodyMarkdown(e.target.value)}
                rows={8}
                placeholder="Markdown is supported."
                disabled={busy}
              />
            </div>
          )}

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
              {busy ? "Adding…" : "Add lesson"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
