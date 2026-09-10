"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Upload, CheckCircle2, XCircle, Loader2, X } from "lucide-react";
import {
  attachUpload,
  createContent,
  presignContentUpload,
} from "@/app/actions/content";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";

type ItemStatus = "pending" | "uploading" | "done" | "error";

interface Item {
  file: File;
  title: string;
  artist: string;
  description: string;
  status: ItemStatus;
  progress: number; // 0-100
  error?: string;
}

/** Filename without its extension, as a sensible default title. */
function titleFromName(name: string): string {
  const dot = name.lastIndexOf(".");
  return (dot > 0 ? name.slice(0, dot) : name).trim();
}

/** PUT one file to the presigned R2 URL, reporting progress. Mirrors the
 *  single-upload dialog: the content-type must match what the presign was
 *  signed with, or R2 rejects it. */
function uploadToR2(
  uploadUrl: string,
  file: File,
  contentType: string,
  onProgress: (pct: number) => void,
): Promise<void> {
  return new Promise<void>((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.open("PUT", uploadUrl);
    xhr.setRequestHeader("content-type", contentType);
    xhr.upload.onprogress = (e) => {
      if (e.lengthComputable) onProgress(Math.round((e.loaded / e.total) * 100));
    };
    xhr.onload = () =>
      xhr.status >= 200 && xhr.status < 300
        ? resolve()
        : reject(new Error(`Upload failed (${xhr.status})`));
    xhr.onerror = () => reject(new Error("Upload failed (network error)"));
    xhr.send(file);
  });
}

export function BulkUploadAudioDialog() {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [items, setItems] = useState<Item[]>([]);
  const [isPremium, setIsPremium] = useState(true);
  const [language, setLanguage] = useState("");

  function reset() {
    setItems([]);
    setIsPremium(true);
    setLanguage("");
  }

  function onPick(files: FileList | null) {
    if (!files) return;
    const next: Item[] = Array.from(files).map((file) => ({
      file,
      title: titleFromName(file.name),
      artist: "",
      description: "",
      status: "pending",
      progress: 0,
    }));
    setItems(next);
  }

  function setItem(index: number, patch: Partial<Item>) {
    setItems((prev) =>
      prev.map((it, i) => (i === index ? { ...it, ...patch } : it)),
    );
  }

  function removeItem(index: number) {
    setItems((prev) => prev.filter((_, i) => i !== index));
  }

  async function uploadOne(item: Item, index: number): Promise<boolean> {
    const title = item.title.trim();
    if (!title) {
      setItem(index, { status: "error", error: "Title is empty" });
      return false;
    }
    setItem(index, { status: "uploading", progress: 0, error: undefined });
    try {
      const created = await createContent({
        kind: "audio",
        title,
        artist: item.artist.trim() || undefined,
        description: item.description.trim() || undefined,
        language: language || undefined,
        isPremium,
      });
      if (!created.ok) throw new Error(created.error);

      const presigned = await presignContentUpload({
        kind: "audio",
        contentId: created.id,
        fileName: item.file.name,
        contentType: item.file.type || "application/octet-stream",
      });
      if (!presigned.ok) throw new Error(presigned.error);

      await uploadToR2(
        presigned.uploadUrl,
        item.file,
        presigned.contentType,
        (pct) => setItem(index, { progress: pct }),
      );

      const attached = await attachUpload({
        kind: "audio",
        contentId: created.id,
        objectKey: presigned.objectKey,
      });
      if (!attached.ok) throw new Error(attached.error);

      setItem(index, { status: "done", progress: 100 });
      return true;
    } catch (e) {
      setItem(index, {
        status: "error",
        error: e instanceof Error ? e.message : "Upload failed",
      });
      return false;
    }
  }

  async function uploadAll() {
    if (items.length === 0) return toast.error("Choose audio files to upload");
    setBusy(true);
    let ok = 0;
    // Sequential on purpose: many parallel large PUTs saturate the uplink and
    // make every one slower, and a clear one-at-a-time progression is easier
    // to read than a dozen bars moving at once.
    for (let i = 0; i < items.length; i++) {
      // Skip ones that already succeeded (e.g. a retry after a partial run).
      if (items[i].status === "done") {
        ok += 1;
        continue;
      }
      const success = await uploadOne(items[i], i);
      if (success) ok += 1;
    }
    setBusy(false);
    const failed = items.length - ok;
    if (failed === 0) {
      toast.success(`Uploaded ${ok} audio${ok === 1 ? "" : "s"}`);
      setOpen(false);
      reset();
    } else {
      toast.error(`${ok} uploaded, ${failed} failed — retry the failed ones`);
    }
    router.refresh();
  }

  const doneCount = items.filter((i) => i.status === "done").length;

  return (
    <Dialog
      open={open}
      onOpenChange={(o) => {
        if (!busy) setOpen(o);
      }}
    >
      <DialogTrigger asChild>
        <Button variant="outline">
          <Upload className="h-4 w-4" />
          Upload multiple
        </Button>
      </DialogTrigger>
      <DialogContent className="max-w-2xl">
        <DialogHeader>
          <DialogTitle>Upload multiple audios</DialogTitle>
          <DialogDescription>
            Pick several files at once. Give each its own name, artist and
            description — they all upload together. Premium and language below
            apply to the whole batch.
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="bulk-files">Audio files</Label>
            <Input
              id="bulk-files"
              type="file"
              accept="audio/*,.mp3,.m4a"
              multiple
              disabled={busy}
              onChange={(e) => onPick(e.target.files)}
            />
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label htmlFor="bulk-lang">Language (all)</Label>
              <Input
                id="bulk-lang"
                value={language}
                onChange={(e) => setLanguage(e.target.value)}
                placeholder="en"
                disabled={busy}
              />
            </div>
            <div className="flex items-end gap-2 pb-1">
              <input
                id="bulk-premium"
                type="checkbox"
                checked={isPremium}
                onChange={(e) => setIsPremium(e.target.checked)}
                disabled={busy}
                className="h-4 w-4 accent-primary"
              />
              <Label htmlFor="bulk-premium">Premium (all)</Label>
            </div>
          </div>

          {items.length > 0 && (
            <div className="max-h-[46vh] space-y-3 overflow-y-auto rounded-md border p-2">
              {items.map((it, i) => (
                <div
                  key={i}
                  className="space-y-2 rounded-md border bg-muted/30 p-2.5"
                >
                  <div className="flex items-center gap-2">
                    <StatusIcon status={it.status} />
                    <p className="min-w-0 flex-1 truncate text-[11px] text-muted-foreground">
                      {it.status === "uploading"
                        ? `Uploading… ${it.progress}%`
                        : it.status === "error"
                          ? (it.error ?? "Failed")
                          : it.status === "done"
                            ? "Uploaded"
                            : it.file.name}
                    </p>
                    {!busy && it.status !== "done" && (
                      <Button
                        type="button"
                        variant="ghost"
                        size="icon"
                        className="h-6 w-6 shrink-0"
                        onClick={() => removeItem(i)}
                      >
                        <X className="h-4 w-4" />
                      </Button>
                    )}
                  </div>

                  <div className="grid gap-2 sm:grid-cols-2">
                    <Input
                      value={it.title}
                      onChange={(e) => setItem(i, { title: e.target.value })}
                      disabled={busy || it.status === "done"}
                      placeholder="Title"
                      className="h-8"
                    />
                    <Input
                      value={it.artist}
                      onChange={(e) => setItem(i, { artist: e.target.value })}
                      disabled={busy || it.status === "done"}
                      placeholder="Artist (optional)"
                      className="h-8"
                    />
                  </div>
                  <Textarea
                    value={it.description}
                    onChange={(e) =>
                      setItem(i, { description: e.target.value })
                    }
                    disabled={busy || it.status === "done"}
                    placeholder="Description (optional)"
                    rows={2}
                  />
                </div>
              ))}
            </div>
          )}
        </div>

        <DialogFooter>
          <span className="mr-auto self-center text-xs text-muted-foreground">
            {items.length > 0
              ? `${doneCount} / ${items.length} uploaded`
              : "No files selected"}
          </span>
          <Button
            type="button"
            variant="outline"
            onClick={() => setOpen(false)}
            disabled={busy}
          >
            Close
          </Button>
          <Button onClick={uploadAll} disabled={busy || items.length === 0}>
            {busy ? "Uploading…" : `Upload ${items.length || ""}`.trim()}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function StatusIcon({ status }: { status: ItemStatus }) {
  if (status === "done") {
    return <CheckCircle2 className="h-4 w-4 shrink-0 text-emerald-600" />;
  }
  if (status === "error") {
    return <XCircle className="h-4 w-4 shrink-0 text-destructive" />;
  }
  if (status === "uploading") {
    return <Loader2 className="h-4 w-4 shrink-0 animate-spin text-primary" />;
  }
  return <div className="h-4 w-4 shrink-0 rounded-full border" />;
}
