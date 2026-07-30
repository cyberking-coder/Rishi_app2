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
import { NativeOption, NativeSelect } from "@/components/ui/native-select";
import { createLesson } from "@/app/actions/courses";
import type { Audio, LessonType, Video } from "@/lib/types";

export function AddLessonDialog({
  courseId,
  moduleId,
  audioLibrary,
  videoLibrary,
}: {
  courseId: string;
  moduleId: string;
  audioLibrary: Audio[];
  videoLibrary: Video[];
}) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);

  const [title, setTitle] = useState("");
  const [lessonType, setLessonType] = useState<LessonType>("audio");
  const [audioId, setAudioId] = useState("");
  const [videoId, setVideoId] = useState("");
  const [bodyMarkdown, setBodyMarkdown] = useState("");

  function reset() {
    setTitle("");
    setLessonType("audio");
    setAudioId("");
    setVideoId("");
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
        videoId: lessonType === "video" ? videoId : undefined,
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
            <NativeSelect
              id="al-type"
              value={lessonType}
              onChange={(e) => setLessonType(e.target.value as LessonType)}
              disabled={busy}
            >
              <NativeOption value="audio">Audio</NativeOption>
              <NativeOption value="video">Video</NativeOption>
              <NativeOption value="text">Text</NativeOption>
            </NativeSelect>
          </div>

          {lessonType === "audio" && (
            <div>
              <Label htmlFor="al-audio">Audio</Label>
              <NativeSelect
                id="al-audio"
                value={audioId}
                onChange={(e) => setAudioId(e.target.value)}
                disabled={busy}
              >
                <NativeOption value="">Select from your library…</NativeOption>
                {audioLibrary.map((a) => (
                  <NativeOption key={a.id} value={a.id}>
                    {a.title}
                    {a.is_premium ? " (premium)" : " (free)"}
                  </NativeOption>
                ))}
              </NativeSelect>
              <p className="mt-1 text-xs text-muted-foreground">
                {audioLibrary.length === 0
                  ? "No published audio yet — upload one in the Audios tab first."
                  : "Only published audio is listed. To add something new, upload it in the Audios tab, then attach it here."}
              </p>
            </div>
          )}

          {lessonType === "video" && (
            <div>
              <Label htmlFor="al-video">Video</Label>
              <NativeSelect
                id="al-video"
                value={videoId}
                onChange={(e) => setVideoId(e.target.value)}
                disabled={busy}
              >
                <NativeOption value="">Select from your library…</NativeOption>
                {videoLibrary.map((v) => (
                  <NativeOption key={v.id} value={v.id}>
                    {v.title}
                    {v.is_premium ? " (premium)" : " (free)"}
                  </NativeOption>
                ))}
              </NativeSelect>
              <p className="mt-1 text-xs text-muted-foreground">
                {videoLibrary.length === 0
                  ? "No published video yet — upload one in the Videos tab first."
                  : "Heads up: the mobile app has no video player yet, so video lessons will show as coming soon until that ships."}
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
