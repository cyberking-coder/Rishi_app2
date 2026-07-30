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
import {
  attachUpload,
  createContent,
  presignContentUpload,
  updateContentStatus,
} from "@/app/actions/content";
import type { Audio, LessonType, Video } from "@/lib/types";

type MediaMode = "existing" | "upload";

function uploadToR2(uploadUrl: string, file: File, onProgress: (msg: string) => void) {
  return new Promise<void>((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.open("PUT", uploadUrl);
    xhr.setRequestHeader("content-type", file.type || "application/octet-stream");
    xhr.upload.onprogress = (e) => {
      if (e.lengthComputable) {
        const pct = Math.round((e.loaded / e.total) * 100);
        onProgress(`Uploading… ${pct}%`);
      }
    };
    xhr.onload = () =>
      xhr.status >= 200 && xhr.status < 300
        ? resolve()
        : reject(new Error(`Upload failed (${xhr.status})`));
    xhr.onerror = () => reject(new Error("Upload failed (network error)"));
    xhr.send(file);
  });
}

export function AddLessonDialog({
  courseId,
  moduleId,
  coursePremium,
  audioLibrary,
  videoLibrary,
}: {
  courseId: string;
  moduleId: string;
  coursePremium: boolean;
  audioLibrary: Audio[];
  videoLibrary: Video[];
}) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [progress, setProgress] = useState<string | null>(null);

  const [title, setTitle] = useState("");
  const [lessonType, setLessonType] = useState<LessonType>("audio");
  const [audioMode, setAudioMode] = useState<MediaMode>("existing");
  const [videoMode, setVideoMode] = useState<MediaMode>("existing");
  const [audioId, setAudioId] = useState("");
  const [videoId, setVideoId] = useState("");
  const [mediaFile, setMediaFile] = useState<File | null>(null);
  const [bodyMarkdown, setBodyMarkdown] = useState("");

  function reset() {
    setTitle("");
    setLessonType("audio");
    setAudioMode("existing");
    setVideoMode("existing");
    setAudioId("");
    setVideoId("");
    setMediaFile(null);
    setBodyMarkdown("");
    setProgress(null);
  }

  /** Uploads mediaFile as a new draft audio/video, publishes it, and
   *  returns its id so it can be attached to the lesson being created. */
  async function uploadNewMedia(kind: "audio" | "video"): Promise<string> {
    if (!mediaFile) throw new Error("Choose a file to upload");

    setProgress("Creating record…");
    const created = await createContent({
      kind,
      title: title.trim(),
      isPremium: coursePremium,
    });
    if (!created.ok) throw new Error(created.error);

    setProgress("Preparing upload…");
    const presigned = await presignContentUpload({
      kind,
      contentId: created.id,
      fileName: mediaFile.name,
      contentType: mediaFile.type || "application/octet-stream",
    });
    if (!presigned.ok) throw new Error(presigned.error);

    await uploadToR2(presigned.uploadUrl, mediaFile, setProgress);

    setProgress("Finalizing…");
    const attached = await attachUpload({
      kind,
      contentId: created.id,
      objectKey: presigned.objectKey,
    });
    if (!attached.ok) throw new Error(attached.error);

    // Lessons can only attach published media (the license functions
    // require it) — publish right away rather than leaving admins to
    // find this content in the Audios/Videos tab and flip it manually.
    await updateContentStatus({ kind, contentId: created.id, status: "published" });

    return created.id;
  }

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!title.trim()) return toast.error("Give the lesson a title");
    if (lessonType === "audio" && audioMode === "existing" && !audioId)
      return toast.error("Pick an audio track, or switch to upload a new one");
    if (lessonType === "video" && videoMode === "existing" && !videoId)
      return toast.error("Pick a video, or switch to upload a new one");

    setBusy(true);
    try {
      let finalAudioId = lessonType === "audio" ? audioId : undefined;
      let finalVideoId = lessonType === "video" ? videoId : undefined;

      if (lessonType === "audio" && audioMode === "upload") {
        finalAudioId = await uploadNewMedia("audio");
      }
      if (lessonType === "video" && videoMode === "upload") {
        finalVideoId = await uploadNewMedia("video");
      }

      setProgress("Adding lesson…");
      const result = await createLesson({
        moduleId,
        courseId,
        title: title.trim(),
        lessonType,
        audioId: finalAudioId,
        videoId: finalVideoId,
        bodyMarkdown: lessonType === "text" ? bodyMarkdown : undefined,
      });
      if (!result.ok) throw new Error(result.error);

      toast.success(
        lessonType === "video" && videoMode === "upload"
          ? "Lesson added — the video is now encoding on Bunny Stream, it'll be playable once that finishes."
          : "Lesson added",
      );
      setOpen(false);
      reset();
      router.refresh();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Could not add lesson");
    } finally {
      setBusy(false);
      setProgress(null);
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
            <div className="space-y-2">
              <div className="flex items-center gap-2">
                <Label className="mb-0">Audio</Label>
                <div className="ml-auto flex overflow-hidden rounded-md border">
                  <button
                    type="button"
                    disabled={busy}
                    onClick={() => setAudioMode("existing")}
                    className={`px-2 py-1 text-xs ${audioMode === "existing" ? "bg-primary text-primary-foreground" : "bg-background"}`}
                  >
                    From library
                  </button>
                  <button
                    type="button"
                    disabled={busy}
                    onClick={() => setAudioMode("upload")}
                    className={`px-2 py-1 text-xs ${audioMode === "upload" ? "bg-primary text-primary-foreground" : "bg-background"}`}
                  >
                    Upload new
                  </button>
                </div>
              </div>

              {audioMode === "existing" ? (
                <>
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
                  <p className="text-xs text-muted-foreground">
                    {audioLibrary.length === 0
                      ? 'No published audio yet — switch to "Upload new" to add one now.'
                      : "Only published audio is listed."}
                  </p>
                </>
              ) : (
                <>
                  <Input
                    type="file"
                    accept="audio/*"
                    disabled={busy}
                    onChange={(e) => setMediaFile(e.target.files?.[0] ?? null)}
                  />
                  <p className="text-xs text-muted-foreground">
                    Uploaded from your device, saved to storage, and published
                    automatically as {coursePremium ? "premium" : "free"}{" "}
                    content (matching this course).
                  </p>
                </>
              )}
            </div>
          )}

          {lessonType === "video" && (
            <div className="space-y-2">
              <div className="flex items-center gap-2">
                <Label className="mb-0">Video</Label>
                <div className="ml-auto flex overflow-hidden rounded-md border">
                  <button
                    type="button"
                    disabled={busy}
                    onClick={() => setVideoMode("existing")}
                    className={`px-2 py-1 text-xs ${videoMode === "existing" ? "bg-primary text-primary-foreground" : "bg-background"}`}
                  >
                    From library
                  </button>
                  <button
                    type="button"
                    disabled={busy}
                    onClick={() => setVideoMode("upload")}
                    className={`px-2 py-1 text-xs ${videoMode === "upload" ? "bg-primary text-primary-foreground" : "bg-background"}`}
                  >
                    Upload new
                  </button>
                </div>
              </div>

              {videoMode === "existing" ? (
                <>
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
                  <p className="text-xs text-muted-foreground">
                    {videoLibrary.length === 0
                      ? 'No published video yet — switch to "Upload new" to add one now.'
                      : "Check the Videos tab shows this one as Ready — a video still encoding on Bunny won't play yet."}
                  </p>
                </>
              ) : (
                <>
                  <Input
                    type="file"
                    accept="video/*"
                    disabled={busy}
                    onChange={(e) => setMediaFile(e.target.files?.[0] ?? null)}
                  />
                  <p className="text-xs text-muted-foreground">
                    Uploaded from your device, then sent to Bunny Stream for
                    encoding — it&apos;ll show as &quot;Encoding&quot; in the
                    Videos tab until it&apos;s ready to play.
                  </p>
                </>
              )}
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
              {busy ? (progress ?? "Adding…") : "Add lesson"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
