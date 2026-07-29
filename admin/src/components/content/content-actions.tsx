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
import {
  deleteContent,
  setContentPremium,
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
}: {
  kind: ContentKind;
  contentId: string;
  status: ContentStatus;
  isPremium: boolean;
}) {
  const router = useRouter();
  const [confirmOpen, setConfirmOpen] = useState(false);
  const coverInputRef = useRef<HTMLInputElement>(null);

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
