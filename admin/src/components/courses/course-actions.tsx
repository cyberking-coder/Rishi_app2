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
import {
  deleteCourse,
  setCoursePremium,
  setCourseStatus,
} from "@/app/actions/courses";
import type { CourseStatus } from "@/lib/types";

export function CourseActions({
  courseId,
  status,
  isPremium,
}: {
  courseId: string;
  status: CourseStatus;
  isPremium: boolean;
}) {
  const router = useRouter();
  const [confirmOpen, setConfirmOpen] = useState(false);

  async function changeStatus(next: CourseStatus) {
    const result = await setCourseStatus({ courseId, status: next });
    if (!result.ok) return toast.error(result.error);
    toast.success(`Marked ${next}`);
    router.refresh();
  }

  async function togglePremium() {
    const result = await setCoursePremium({ courseId, isPremium: !isPremium });
    if (!result.ok) return toast.error(result.error);
    toast.success(isPremium ? "Marked free" : "Marked premium");
    router.refresh();
  }

  async function onDelete() {
    const result = await deleteCourse(courseId);
    if (!result.ok) return toast.error(result.error);
    toast.success("Course deleted");
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
          <DropdownMenuItem onClick={() => router.push(`/courses/${courseId}`)}>
            Edit content
          </DropdownMenuItem>
          <DropdownMenuItem onClick={togglePremium}>
            Mark {isPremium ? "free" : "premium"}
          </DropdownMenuItem>
          <DropdownMenuSeparator />
          {status !== "published" && (
            <DropdownMenuItem onClick={() => changeStatus("published")}>
              Publish
            </DropdownMenuItem>
          )}
          {status !== "archived" && (
            <DropdownMenuItem onClick={() => changeStatus("archived")}>
              Archive
            </DropdownMenuItem>
          )}
          {status !== "draft" && (
            <DropdownMenuItem onClick={() => changeStatus("draft")}>
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
            <DialogTitle>Delete this course?</DialogTitle>
            <DialogDescription>
              Its modules and lessons go with it. The audio and video files
              the lessons pointed at are not deleted — they stay in your
              library.
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
