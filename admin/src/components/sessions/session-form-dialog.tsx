"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import {
  createLiveSession,
  updateLiveSession,
  uploadSessionThumbnail,
} from "@/app/actions/sessions";
import type { LiveSession } from "@/lib/types";

/// `datetime-local` wants "YYYY-MM-DDTHH:mm" in the browser's own zone,
/// while the database stores UTC. Converting through the Date object is
/// what makes "7pm" mean 7pm to the admin typing it, wherever they are.
function toLocalInputValue(iso: string): string {
  const d = new Date(iso);
  const pad = (n: number) => n.toString().padStart(2, "0");
  return (
    `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}` +
    `T${pad(d.getHours())}:${pad(d.getMinutes())}`
  );
}

/// One dialog for both add and edit — the fields are identical, and two
/// copies would drift the moment either changed.
export function SessionFormDialog({
  session,
  trigger,
}: {
  session?: LiveSession;
  trigger?: React.ReactNode;
}) {
  const router = useRouter();
  const editing = Boolean(session);

  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);

  const [title, setTitle] = useState(session?.title ?? "");
  const [description, setDescription] = useState(session?.description ?? "");
  const [joinUrl, setJoinUrl] = useState(session?.join_url ?? "");
  const [startsAt, setStartsAt] = useState(
    session ? toLocalInputValue(session.starts_at) : "",
  );
  const [duration, setDuration] = useState(
    String(session?.duration_minutes ?? 60),
  );
  const [thumbnailUrl, setThumbnailUrl] = useState(
    session?.thumbnail_url ?? "",
  );
  const [uploading, setUploading] = useState(false);

  function reset() {
    if (editing) return;
    setTitle("");
    setDescription("");
    setJoinUrl("");
    setStartsAt("");
    setDuration("60");
    setThumbnailUrl("");
  }

  async function onPickThumbnail(file: File) {
    setUploading(true);
    try {
      const base64 = Buffer.from(await file.arrayBuffer()).toString("base64");
      const result = await uploadSessionThumbnail({
        fileName: file.name,
        contentType: file.type || "image/jpeg",
        base64,
      });
      if (!result.ok) throw new Error(result.error);
      setThumbnailUrl(result.url);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Upload failed");
    } finally {
      setUploading(false);
    }
  }

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    try {
      const payload = {
        title,
        description: description || undefined,
        joinUrl,
        // The input is local-time; toISOString converts it once, here,
        // so nothing downstream has to guess a zone.
        startsAt: new Date(startsAt).toISOString(),
        durationMinutes: Number(duration),
        thumbnailUrl: thumbnailUrl || undefined,
      };

      const result = session
        ? await updateLiveSession({ ...payload, id: session.id })
        : await createLiveSession(payload);
      if (!result.ok) throw new Error(result.error);

      toast.success(editing ? "Session updated" : "Session scheduled");
      setOpen(false);
      reset();
      router.refresh();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Could not save");
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
        {trigger ?? (
          <Button>
            <Plus className="h-4 w-4" />
            Schedule session
          </Button>
        )}
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>
            {editing ? "Edit session" : "Schedule a live session"}
          </DialogTitle>
          <DialogDescription>
            Shown in the app&apos;s Watch section. Everyone with the app gets a
            notification an hour, 30 minutes and 5 minutes before it starts.
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={onSubmit} className="space-y-4">
          <div>
            <Label htmlFor="ls-title">Title</Label>
            <Input
              id="ls-title"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="Sunday morning satsang"
              disabled={busy}
            />
          </div>

          <div>
            <Label htmlFor="ls-url">Meeting link</Label>
            <Input
              id="ls-url"
              value={joinUrl}
              onChange={(e) => setJoinUrl(e.target.value)}
              placeholder="https://zoom.us/j/…"
              disabled={busy}
            />
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <Label htmlFor="ls-start">Starts</Label>
              <Input
                id="ls-start"
                type="datetime-local"
                value={startsAt}
                onChange={(e) => setStartsAt(e.target.value)}
                disabled={busy}
              />
            </div>
            <div>
              <Label htmlFor="ls-duration">Duration (minutes)</Label>
              <Input
                id="ls-duration"
                type="number"
                min={1}
                value={duration}
                onChange={(e) => setDuration(e.target.value)}
                disabled={busy}
              />
            </div>
          </div>

          <div>
            <Label htmlFor="ls-desc">Description</Label>
            <Textarea
              id="ls-desc"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              rows={2}
              disabled={busy}
            />
          </div>

          <div>
            <Label htmlFor="ls-thumb">Thumbnail</Label>
            {thumbnailUrl && (
              /* eslint-disable-next-line @next/next/no-img-element */
              <img
                src={thumbnailUrl}
                alt=""
                className="mb-2 aspect-video w-full rounded-lg object-cover"
              />
            )}
            <Input
              id="ls-thumb"
              type="file"
              accept="image/*"
              disabled={busy || uploading}
              onChange={(e) => {
                const file = e.target.files?.[0];
                if (file) void onPickThumbnail(file);
              }}
            />
            <p className="mt-1 text-xs text-muted-foreground">
              {uploading
                ? "Uploading…"
                : "Optional. Without one the app draws a plain card."}
            </p>
          </div>

          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => setOpen(false)}
              disabled={busy}
            >
              Cancel
            </Button>
            <Button
              type="submit"
              disabled={
                busy || uploading || !title.trim() || !joinUrl.trim() || !startsAt
              }
            >
              {busy ? "Saving…" : editing ? "Save changes" : "Schedule"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
