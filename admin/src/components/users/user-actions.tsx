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
  updateUserStatus,
  setUserAccessDays,
  setUserAccessMinutes,
  revokeUserAccess,
} from "@/app/actions/users";
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

  async function extendAccess(days: number) {
    const result = await setUserAccessDays(userId, days);
    if (!result.ok) return toast.error(result.error);
    toast.success(`Access set to ${days} more days`);
    router.refresh();
  }

  async function endAccess() {
    const result = await revokeUserAccess(userId);
    if (!result.ok) return toast.error(result.error);
    toast.success("Access ended — content hidden & downloads purged on next open");
    router.refresh();
  }

  async function testMinutes(minutes: number) {
    const result = await setUserAccessMinutes(userId, minutes);
    if (!result.ok) return toast.error(result.error);
    toast.success(`Access set to expire in ${minutes} minutes`);
    router.refresh();
  }

  async function customDays() {
    const input = window.prompt(
      "Grant access for how many days? (use 0 for unlimited)",
      "30",
    );
    if (input === null) return;
    const days = Number(input);
    if (Number.isNaN(days) || days < 0) return toast.error("Enter a valid number");
    const result = await setUserAccessDays(userId, days);
    if (!result.ok) return toast.error(result.error);
    toast.success(days === 0 ? "Access set to unlimited" : `Access set to ${days} days`);
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
        <DropdownMenuLabel>Access</DropdownMenuLabel>
        <DropdownMenuItem onClick={() => extendAccess(30)}>
          Grant 30 more days
        </DropdownMenuItem>
        <DropdownMenuItem onClick={() => extendAccess(7)}>
          Grant 7 more days
        </DropdownMenuItem>
        <DropdownMenuItem onClick={customDays}>
          Custom days…
        </DropdownMenuItem>
        <DropdownMenuItem onClick={() => testMinutes(5)}>
          Test: expire in 5 min
        </DropdownMenuItem>
        <DropdownMenuItem onClick={() => testMinutes(10)}>
          Test: expire in 10 min
        </DropdownMenuItem>
        <DropdownMenuItem className="text-destructive" onClick={endAccess}>
          End access now
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
