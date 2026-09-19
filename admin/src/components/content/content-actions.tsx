"use client";

import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { MoreHorizontal } from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import {
  deleteContent,
  setContentPremium,
  updateContent,
  updateContentStatus,
  uploadCover,
} from "@/app/actions/content";
import type { ContentKind, ContentStatus } from "@/lib/types";

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

export function ContentActions({
  kind,
  contentId,
  status,
  isPremium,
  title = "",
  description = "",
  artist = "",
  language = "",
  album = "",
}: {
  kind: ContentKind;
  contentId: string;
  status: ContentStatus;
  isPremium: boolean;
  title?: string;
  description?: string | null;
  artist?: string | null;
  language?: string | null;
  album?: string | null;
}) {
  const router = useRouter();
  const [confirmOpen, setConfirmOpen] = useState(false);
  const coverInputRef = useRef<HTMLInputElement>(null);

  // Edit-details dialog state. Fields are seeded from the current values each
  // time the dialog opens so an edit always starts from what's live.
  const [editOpen, setEditOpen] = useState(false);
  const [saving, setSaving] = useState(false);
  const [fTitle, setFTitle] = useState(title);
  const [fArtist, setFArtist] = useState(artist ?? "");
  const [fDescription, setFDescription] = useState(description ?? "");
  const [fLanguage, setFLanguage] = useState(language ?? "");
  const [fAlbum, setFAlbum] = useState(album ?? "");

  function openEdit() {
    setFTitle(title);
    setFArtist(artist ?? "");
    setFDescription(description ?? "");
    setFLanguage(language ?? "");
    setFAlbum(album ?? "");
    setEditOpen(true);
  }

  async function onSaveEdit() {
    if (!fTitle.trim()) return toast.error("Title can't be empty.");
    setSaving(true);
    const result = await updateContent({
      kind,
      contentId,
      title: fTitle,
      description: fDescription,
      language: fLanguage,
      ...(kind === "audio" ? { artist: fArtist, album: fAlbum } : {}),
    });
    setSaving(false);
    if (!result.ok) return toast.error(result.error);
    toast.success("Details updated");
    setEditOpen(false);
    router.refresh();
  }

  async function onCoverPicked(e: React.ChangeEvent<HTMLInputElement>) {
    const f = e.target.files?.[0];
    e.target.value = ""; // allow re-picking the same file later
    if (!f) return;
    toast.info("Uploading cover…");
    const base64 = await fileToBase64(f);
    const result = await uploadCover({
      kind,
      contentId,
      fileName: f.name,
      contentType: f.type || "image/jpeg",
      base64,
    });
    if (!result.ok) return toast.error(result.error);
    toast.success("Cover image updated");
    router.refresh();
  }

  async function setStatus(next: ContentStatus) {
    const result = await updateContentStatus({ kind, contentId, status: next });
    if (!result.ok) return toast.error(result.error);
    toast.success(`Marked ${next}`);
    router.refresh();
  }

  async function togglePremium() {
    const result = await setContentPremium({
      kind,
      contentId,
      isPremium: !isPremium,
    });
    if (!result.ok) return toast.error(result.error);
    toast.success(isPremium ? "Marked free" : "Marked premium");
    router.refresh();
  }

  async function onDelete() {
    const result = await deleteContent({ kind, contentId });
    if (!result.ok) return toast.error(result.error);
    toast.success("Deleted");
    setConfirmOpen(false);
    router.refresh();
  }

  return (
    <>
      <input
        ref={coverInputRef}
        type="file"
        accept="image/*"
        className="hidden"
        onChange={onCoverPicked}
      />
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="ghost" size="icon">
            <MoreHorizontal className="h-4 w-4" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuLabel>Actions</DropdownMenuLabel>
          <DropdownMenuItem onClick={openEdit}>Edit details</DropdownMenuItem>
          <DropdownMenuItem onClick={() => coverInputRef.current?.click()}>
            Set cover image
          </DropdownMenuItem>
          <DropdownMenuItem onClick={togglePremium}>
            Mark {isPremium ? "free" : "premium"}
          </DropdownMenuItem>
          <DropdownMenuSeparator />
          {status !== "published" && (
            <DropdownMenuItem onClick={() => setStatus("published")}>
              Publish
            </DropdownMenuItem>
          )}
          {status !== "archived" && (
            <DropdownMenuItem onClick={() => setStatus("archived")}>
              Archive
            </DropdownMenuItem>
          )}
          {status !== "draft" && (
            <DropdownMenuItem onClick={() => setStatus("draft")}>
              Move to draft
            </DropdownMenuItem>
          )}
          <DropdownMenuSeparator />
          <DropdownMenuItem
            className="text-destructive"
            onClick={() => setConfirmOpen(true)}
          >
            Delete
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>

      <Dialog open={editOpen} onOpenChange={setEditOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Edit {kind} details</DialogTitle>
            <DialogDescription>
              Change the {kind}&apos;s name and description. The media file
              itself is not affected. Works after publishing too.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-2">
            <div className="space-y-1.5">
              <Label htmlFor="ca-title">Title</Label>
              <Input
                id="ca-title"
                value={fTitle}
                onChange={(e) => setFTitle(e.target.value)}
              />
            </div>
            {kind === "audio" && (
              <div className="space-y-1.5">
                <Label htmlFor="ca-artist">Artist</Label>
                <Input
                  id="ca-artist"
                  value={fArtist}
                  onChange={(e) => setFArtist(e.target.value)}
                />
              </div>
            )}
            <div className="space-y-1.5">
              <Label htmlFor="ca-desc">Description</Label>
              <Textarea
                id="ca-desc"
                rows={4}
                value={fDescription}
                onChange={(e) => setFDescription(e.target.value)}
              />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="ca-lang">Language</Label>
              <Input
                id="ca-lang"
                placeholder="en"
                value={fLanguage}
                onChange={(e) => setFLanguage(e.target.value)}
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setEditOpen(false)}>
              Cancel
            </Button>
            <Button onClick={onSaveEdit} disabled={saving}>
              {saving ? "Saving…" : "Save changes"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={confirmOpen} onOpenChange={setConfirmOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Delete this {kind}?</DialogTitle>
            <DialogDescription>
              This permanently removes the record. The stored media file is
              not automatically deleted from R2.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setConfirmOpen(false)}>
              Cancel
            </Button>
            <Button variant="destructive" onClick={onDelete}>
              Delete
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}
