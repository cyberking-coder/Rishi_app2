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
import { NativeOption, NativeSelect } from "@/components/ui/native-select";
import { createYoutubeVideo } from "@/app/actions/youtube";
import { parseYoutubeId, youtubeThumbnail } from "@/lib/youtube";
import type { Category } from "@/lib/types";

export function AddYoutubeDialog({ categories }: { categories: Category[] }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);

  const [title, setTitle] = useState("");
  const [url, setUrl] = useState("");
  const [description, setDescription] = useState("");
  const [categoryId, setCategoryId] = useState("");

  // Parsed client-side purely for the preview; the server re-parses and
  // is the one that decides whether the link is acceptable.
  const previewId = url.trim() ? parseYoutubeId(url) : null;

  function reset() {
    setTitle("");
    setUrl("");
    setDescription("");
    setCategoryId("");
  }

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    try {
      const result = await createYoutubeVideo({
        title,
        url,
        description: description || undefined,
        categoryId: categoryId || undefined,
      });
      if (!result.ok) throw new Error(result.error);

      toast.success("Video added");
      setOpen(false);
      reset();
      router.refresh();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Could not add video");
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
        <Button>
          <Plus className="h-4 w-4" />
          Add video
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Add a YouTube video</DialogTitle>
          <DialogDescription>
            Shown in the app&apos;s Watch section. Tapping it opens YouTube.
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={onSubmit} className="space-y-4">
          <div>
            <Label htmlFor="yt-url">YouTube link</Label>
            <Input
              id="yt-url"
              value={url}
              onChange={(e) => setUrl(e.target.value)}
              placeholder="https://www.youtube.com/watch?v=…"
              disabled={busy}
            />
            {url.trim() && !previewId && (
              <p className="mt-1 text-xs text-destructive">
                That doesn&apos;t look like a YouTube link.
              </p>
            )}
          </div>

          {previewId && (
            /* eslint-disable-next-line @next/next/no-img-element */
            <img
              src={youtubeThumbnail(previewId)}
              alt=""
              className="aspect-video w-full rounded-lg object-cover"
            />
          )}

          <div>
            <Label htmlFor="yt-title">Title</Label>
            <Input
              id="yt-title"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="How it appears in the app"
              disabled={busy}
            />
          </div>

          <div>
            <Label htmlFor="yt-desc">Description</Label>
            <Textarea
              id="yt-desc"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              rows={2}
              disabled={busy}
            />
          </div>

          <div>
            <Label htmlFor="yt-category">Category</Label>
            <NativeSelect
              id="yt-category"
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

          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => setOpen(false)}
              disabled={busy}
            >
              Cancel
            </Button>
            <Button type="submit" disabled={busy || !previewId || !title.trim()}>
              {busy ? "Adding…" : "Add video"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
