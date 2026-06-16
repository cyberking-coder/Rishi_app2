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
import { updateUserStatus } from "@/app/actions/users";
import { resetUserDevices } from "@/app/actions/devices";
import type { UserStatus } from "@/lib/types";

export function UserActions({
  userId,
  status,
}: {
  userId: string;
  status: UserStatus;
}) {
  const router = useRouter();

  async function setStatus(next: UserStatus) {
    const result = await updateUserStatus(userId, next);
    if (!result.ok) return toast.error(result.error);
    toast.success(`User ${next}`);
    router.refresh();
  }

  async function resetDevices() {
    const result = await resetUserDevices(userId);
    if (!result.ok) return toast.error(result.error);
    toast.success("Device lock reset — user can register a new device");
    router.refresh();
  }

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" size="icon">
          <MoreHorizontal className="h-4 w-4" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        <DropdownMenuLabel>Actions</DropdownMenuLabel>
        <DropdownMenuItem onClick={resetDevices}>
          Reset device
        </DropdownMenuItem>
        <DropdownMenuSeparator />
        {status !== "active" && (
          <DropdownMenuItem onClick={() => setStatus("active")}>
            Activate
          </DropdownMenuItem>
        )}
        {status !== "suspended" && (
          <DropdownMenuItem onClick={() => setStatus("suspended")}>
            Suspend
          </DropdownMenuItem>
        )}
        {status !== "banned" && (
          <DropdownMenuItem
            className="text-destructive"
            onClick={() => setStatus("banned")}
          >
            Ban
          </DropdownMenuItem>
        )}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
