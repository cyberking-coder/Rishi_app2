"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Upload } from "lucide-react";
import {
  attachUpload,
  createContent,
  presignContentUpload,
  uploadCover,
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
import type { ContentKind } from "@/lib/types";

export function UploadContentDialog({ kind }: { kind: ContentKind }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [progress, setProgress] = useState<string | null>(null);

  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [language, setLanguage] = useState("");
  const [artist, setArtist] = useState("");
  const [isPremium, setIsPremium] = useState(true);
  const [file, setFile] = useState<File | null>(null);
  const [cover, setCover] = useState<File | null>(null);

  function reset() {
    setTitle("");
    setDescription("");
    setLanguage("");
    setArtist("");
    setIsPremium(true);
    setFile(null);
    setCover(null);
    setProgress(null);
  }

  function fileToBase64(f: File): Promise<string> {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => {
        // strip the "data:...;base64," prefix
        const result = reader.result as string;
        resolve(result.split(",")[1] ?? "");
      };
      reader.onerror = () => reject(new Error("Could not read image"));
      reader.readAsDataURL(f);
    });
  }

  async function uploadToR2(uploadUrl: string, f: File) {
    await new Promise<void>((resolve, reject) => {
      const xhr = new XMLHttpRequest();
      xhr.open("PUT", uploadUrl);
      xhr.setRequestHeader("content-type", f.type || "application/octet-stream");
      xhr.upload.onprogress = (e) => {
        if (e.lengthComputable) {
          const pct = Math.round((e.loaded / e.total) * 100);
          const mb = (e.loaded / 1024 / 1024).toFixed(1);
          const total = (e.total / 1024 / 1024).toFixed(1);
          setProgress(`Uploading… ${pct}% (${mb} / ${total} MB)`);
        }
      };
      xhr.onload = () => xhr.status >= 200 && xhr.status < 300 ? resolve() : reject(new Error(`Upload failed (${xhr.status})`));
      xhr.onerror = () => reject(new Error("Upload failed (network error)"));
      xhr.send(f);
    });
  }

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!file) return toast.error("Choose a file to upload");
    setBusy(true);

    try {
      setProgress("Creating record…");
      const created = await createContent({
        kind,
        title,
        description: description || undefined,
        language: language || undefined,
        isPremium,
        artist: kind === "audio" ? artist || undefined : undefined,
      });
      if (!created.ok) throw new Error(created.error);

      setProgress("Preparing upload…");
      const presigned = await presignContentUpload({
        kind,
        contentId: created.id,
        fileName: file.name,
        contentType: file.type || "application/octet-stream",
      });
      if (!presigned.ok) throw new Error(presigned.error);

      setProgress("Uploading to storage…");
      await uploadToR2(presigned.uploadUrl, file);

      setProgress("Finalizing…");
      const attached = await attachUpload({
        kind,
        contentId: created.id,
        objectKey: presigned.objectKey,
      });
      if (!attached.ok) throw new Error(attached.error);

      if (cover) {
        setProgress("Uploading cover…");
        const base64 = await fileToBase64(cover);
        const coverResult = await uploadCover({
          kind,
          contentId: created.id,
          fileName: cover.name,
          contentType: cover.type || "image/jpeg",
          base64,
        });
        // Non-fatal: the audio is already uploaded; warn but don't fail.
        if (!coverResult.ok) {
          toast.error(`Cover image failed: ${coverResult.error}`);
        }
      }

      toast.success(`${kind === "video" ? "Video" : "Audio"} uploaded`);
      setOpen(false);
      reset();
      router.refresh();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Upload failed");
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
        <Button>
          <Upload className="h-4 w-4" />
          Upload {kind}
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Upload {kind}</DialogTitle>
          <DialogDescription>
            Creates a draft, uploads the file directly to R2, then marks it
            processing.
          </DialogDescription>
        </DialogHeader>
        <form onSubmit={onSubmit} className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="uc-title">Title</Label>
            <Input
              id="uc-title"
              required
              value={title}
              onChange={(e) => setTitle(e.target.value)}
            />
          </div>
          {kind === "audio" && (
            <div className="space-y-2">
              <Label htmlFor="uc-artist">Artist</Label>
              <Input
                id="uc-artist"
                value={artist}
                onChange={(e) => setArtist(e.target.value)}
              />
            </div>
          )}
          <div className="space-y-2">
            <Label htmlFor="uc-desc">Description</Label>
            <Textarea
              id="uc-desc"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
            />
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label htmlFor="uc-lang">Language</Label>
              <Input
                id="uc-lang"
                value={language}
                onChange={(e) => setLanguage(e.target.value)}
                placeholder="en"
              />
            </div>
            <div className="flex items-end gap-2 pb-1">
              <input
                id="uc-premium"
                type="checkbox"
                checked={isPremium}
                onChange={(e) => setIsPremium(e.target.checked)}
                className="h-4 w-4 accent-primary"
              />
              <Label htmlFor="uc-premium">Premium content</Label>
            </div>
          </div>
          <div className="space-y-2">
            <Label htmlFor="uc-file">File</Label>
            <Input
              id="uc-file"
              type="file"
              accept={kind === "video" ? "video/*" : "audio/*"}
              required
              onChange={(e) => setFile(e.target.files?.[0] ?? null)}
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="uc-cover">Cover image (optional)</Label>
            <Input
              id="uc-cover"
              type="file"
              accept="image/*"
              onChange={(e) => setCover(e.target.files?.[0] ?? null)}
            />
            <p className="text-xs text-muted-foreground">
              Shown on the audio card in the app. Square images look best.
            </p>
          </div>
          <DialogFooter>
            <Button type="submit" disabled={busy}>
              {busy ? (progress ?? "Working…") : "Upload"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
