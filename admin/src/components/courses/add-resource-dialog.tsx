"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Paperclip } from "lucide-react";
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
import { NativeOption, NativeSelect } from "@/components/ui/native-select";
import {
  addLessonResource,
  uploadLessonResource,
} from "@/app/actions/courses";
import type { ResourceType } from "@/lib/types";

const ACCEPT: Record<string, string> = {
  pdf: "application/pdf",
  image: "image/*",
  file: "*/*",
};

function fileToBase64(f: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve((reader.result as string).split(",")[1] ?? "");
    reader.onerror = () => reject(new Error("Could not read file"));
    reader.readAsDataURL(f);
  });
}

/** Attaches a handout or link to an existing lesson. */
export function AddResourceDialog({
  lessonId,
  courseId,
}: {
  lessonId: string;
  courseId: string;
}) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);

  const [resourceType, setResourceType] = useState<ResourceType>("pdf");
  const [title, setTitle] = useState("");
  const [file, setFile] = useState<File | null>(null);
  const [url, setUrl] = useState("");

  const isLink = resourceType === "link";

  function reset() {
    setResourceType("pdf");
    setTitle("");
    setFile(null);
    setUrl("");
  }

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (isLink && !url.trim()) return toast.error("Paste the link");
    if (!isLink && !file) return toast.error("Choose a file");

    setBusy(true);
    try {
      let finalUrl = url.trim();

      if (!isLink && file) {
        const base64 = await fileToBase64(file);
        const uploaded = await uploadLessonResource({
          courseId,
          fileName: file.name,
          contentType: file.type || "application/octet-stream",
          base64,
        });
        if (!uploaded.ok) throw new Error(uploaded.error);
        finalUrl = uploaded.url;
      }

      const result = await addLessonResource({
        lessonId,
        courseId,
        // Falls back to the filename, which is usually what the admin
        // would have typed anyway.
        title: title.trim() || file?.name || "Resource",
        resourceType,
        url: finalUrl,
      });
      if (!result.ok) throw new Error(result.error);

      toast.success("Resource attached");
      setOpen(false);
      reset();
      router.refresh();
    } catch (err) {
      toast.error(
        err instanceof Error ? err.message : "Could not attach resource",
      );
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
        <Button variant="ghost" size="icon" title="Attach a resource">
          <Paperclip className="h-4 w-4" />
        </Button>
      </DialogTrigger>

      <DialogContent>
        <DialogHeader>
          <DialogTitle>Attach a resource</DialogTitle>
          <DialogDescription>
            Handouts and links shown alongside this lesson in the app.
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={onSubmit} className="space-y-4">
          <div>
            <Label htmlFor="ar-type">Type</Label>
            <NativeSelect
              id="ar-type"
              value={resourceType}
              onChange={(e) => {
                setResourceType(e.target.value as ResourceType);
                setFile(null);
                setUrl("");
              }}
              disabled={busy}
            >
              <NativeOption value="pdf">PDF</NativeOption>
              <NativeOption value="image">Image</NativeOption>
              <NativeOption value="file">Downloadable file</NativeOption>
              <NativeOption value="link">Link</NativeOption>
            </NativeSelect>
          </div>

          {isLink ? (
            <div>
              <Label htmlFor="ar-url">Link</Label>
              <Input
                id="ar-url"
                type="url"
                value={url}
                onChange={(e) => setUrl(e.target.value)}
                placeholder="https://…"
                disabled={busy}
              />
              <p className="mt-1 text-xs text-muted-foreground">
                A YouTube video, Zoom room, Google Doc — anything with a URL.
              </p>
            </div>
          ) : (
            <div>
              <Label htmlFor="ar-file">File</Label>
              <Input
                id="ar-file"
                type="file"
                accept={ACCEPT[resourceType]}
                disabled={busy}
                onChange={(e) => setFile(e.target.files?.[0] ?? null)}
              />
              <p className="mt-1 text-xs text-muted-foreground">
                Max 25 MB. For anything larger, host it and attach a link.
              </p>
            </div>
          )}

          <div>
            <Label htmlFor="ar-title">Name</Label>
            <Input
              id="ar-title"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder={file?.name ?? "Shown in the app"}
              disabled={busy}
            />
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
            <Button type="submit" disabled={busy}>
              {busy ? "Attaching…" : "Attach"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
