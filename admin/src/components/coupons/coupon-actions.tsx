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
import { deleteCoupon, setCouponActive } from "@/app/actions/coupons";

export function CouponActions({
  couponId,
  isActive,
}: {
  couponId: string;
  isActive: boolean;
}) {
  const router = useRouter();

  async function toggle() {
    const result = await setCouponActive({ couponId, isActive: !isActive });
    if (!result.ok) return toast.error(result.error);
    toast.success(isActive ? "Coupon disabled" : "Coupon enabled");
    router.refresh();
  }

  async function remove() {
    if (!confirm("Delete this coupon? Past redemptions are kept.")) return;
    const result = await deleteCoupon(couponId);
    if (!result.ok) return toast.error(result.error);
    toast.success("Coupon deleted");
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
        <DropdownMenuItem onClick={toggle}>
          {isActive ? "Disable" : "Enable"}
        </DropdownMenuItem>
        <DropdownMenuSeparator />
        <DropdownMenuItem className="text-destructive" onClick={remove}>
          Delete
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
