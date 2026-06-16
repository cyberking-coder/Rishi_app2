"use client";

import { useState } from "react";
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
import { deleteContent, updateContentStatus } from "@/app/actions/content";
import type { ContentKind, ContentStatus } from "@/lib/types";

export function ContentActions({
  kind,
  contentId,
  status,
}: {
  kind: ContentKind;
  contentId: string;
  status: ContentStatus;
}) {
  const router = useRouter();
  const [confirmOpen, setConfirmOpen] = useState(false);

  async function setStatus(next: ContentStatus) {
    const result = await updateContentStatus({ kind, contentId, status: next });
    if (!result.ok) return toast.error(result.error);
    toast.success(`Marked ${next}`);
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
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="ghost" size="icon">
            <MoreHorizontal className="h-4 w-4" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuLabel>Actions</DropdownMenuLabel>
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
