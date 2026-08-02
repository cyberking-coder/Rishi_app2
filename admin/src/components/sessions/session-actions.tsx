"use client";

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
  deleteLiveSession,
  setLiveSessionStatus,
} from "@/app/actions/sessions";
import { SessionFormDialog } from "./session-form-dialog";
import type { LiveSession } from "@/lib/types";

export function SessionActions({ session }: { session: LiveSession }) {
  const router = useRouter();
  const cancelled = session.status === "cancelled";

  async function toggleStatus() {
    const result = await setLiveSessionStatus({
      id: session.id,
      status: cancelled ? "scheduled" : "cancelled",
    });
    if (!result.ok) return toast.error(result.error);
    toast.success(cancelled ? "Session restored" : "Session cancelled");
    router.refresh();
  }

  async function remove() {
    if (
      !confirm(
        "Delete this session? Cancelling instead keeps the card visible so " +
          "anyone expecting it can see it was called off.",
      )
    ) {
      return;
    }
    const result = await deleteLiveSession(session.id);
    if (!result.ok) return toast.error(result.error);
    toast.success("Deleted");
    router.refresh();
  }

  return (
    <div className="flex items-center justify-end gap-1">
      <SessionFormDialog
        session={session}
        trigger={
          <Button variant="ghost" size="sm">
            Edit
          </Button>
        }
      />
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="ghost" size="icon">
            <MoreHorizontal className="h-4 w-4" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuLabel>Actions</DropdownMenuLabel>
          <DropdownMenuItem onClick={toggleStatus}>
            {cancelled ? "Restore" : "Cancel session"}
          </DropdownMenuItem>
          <DropdownMenuSeparator />
          <DropdownMenuItem className="text-destructive" onClick={remove}>
            Delete
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  );
}
