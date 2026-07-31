"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { NativeOption, NativeSelect } from "@/components/ui/native-select";
import { createCoupon } from "@/app/actions/coupons";
import type { Course } from "@/lib/types";

export function CreateCouponDialog({
  courses,
}: {
  courses: Pick<Course, "id" | "title">[];
}) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);

  const [code, setCode] = useState("");
  const [discountType, setDiscountType] = useState<"percent" | "flat">("percent");
  const [discountValue, setDiscountValue] = useState("10");
  const [courseId, setCourseId] = useState("");
  const [maxRedemptions, setMaxRedemptions] = useState("");
  const [expiresAt, setExpiresAt] = useState("");

  function reset() {
    setCode("");
    setDiscountType("percent");
    setDiscountValue("10");
    setCourseId("");
    setMaxRedemptions("");
    setExpiresAt("");
  }

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    try {
      const result = await createCoupon({
        code,
        discountType,
        discountValue: Number(discountValue),
        courseId: courseId || undefined,
        maxRedemptions: maxRedemptions.trim() ? Number(maxRedemptions) : null,
        // A date input gives a local calendar day; treat it as end-of-day
        // so a coupon "expiring on the 5th" is usable all of the 5th.
        expiresAt: expiresAt ? `${expiresAt}T23:59:59` : null,
      });
      if (!result.ok) throw new Error(result.error);

      toast.success("Coupon created");
      setOpen(false);
      reset();
      router.refresh();
    } catch (err) {
      toast.error(
        err instanceof Error ? err.message : "Could not create coupon",
      );
    } finally {
      setBusy(false);
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
        <Button>New coupon</Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>New coupon</DialogTitle>
        </DialogHeader>

        <form onSubmit={onSubmit} className="space-y-4">
          <div>
            <Label htmlFor="cp-code">Code</Label>
            <Input
              id="cp-code"
              value={code}
              onChange={(e) => setCode(e.target.value.toUpperCase())}
              placeholder="LAUNCH20"
              className="font-mono uppercase"
              disabled={busy}
            />
            <p className="mt-1 text-xs text-muted-foreground">
              Letters, numbers and dashes. Buyers type this at checkout.
            </p>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div>
              <Label htmlFor="cp-type">Discount type</Label>
              <NativeSelect
                id="cp-type"
                value={discountType}
                onChange={(e) =>
                  setDiscountType(e.target.value as "percent" | "flat")
                }
                disabled={busy}
              >
                <NativeOption value="percent">Percentage</NativeOption>
                <NativeOption value="flat">Flat amount</NativeOption>
              </NativeSelect>
            </div>
            <div>
              <Label htmlFor="cp-value">
                {discountType === "percent" ? "Percent off" : "Rupees off"}
              </Label>
              <Input
                id="cp-value"
                type="number"
                min={1}
                max={discountType === "percent" ? 100 : undefined}
                value={discountValue}
                onChange={(e) => setDiscountValue(e.target.value)}
                disabled={busy}
              />
            </div>
          </div>

          <div>
            <Label htmlFor="cp-course">Applies to</Label>
            <NativeSelect
              id="cp-course"
              value={courseId}
              onChange={(e) => setCourseId(e.target.value)}
              disabled={busy}
            >
              <NativeOption value="">All courses</NativeOption>
              {courses.map((c) => (
                <NativeOption key={c.id} value={c.id}>
                  {c.title}
                </NativeOption>
              ))}
            </NativeSelect>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div>
              <Label htmlFor="cp-max">Usage limit</Label>
              <Input
                id="cp-max"
                type="number"
                min={1}
                value={maxRedemptions}
                onChange={(e) => setMaxRedemptions(e.target.value)}
                placeholder="Unlimited"
                disabled={busy}
              />
            </div>
            <div>
              <Label htmlFor="cp-expiry">Expires</Label>
              <Input
                id="cp-expiry"
                type="date"
                value={expiresAt}
                onChange={(e) => setExpiresAt(e.target.value)}
                disabled={busy}
              />
            </div>
          </div>

          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => setOpen(false)}
              disabled={busy}
            >
              Cancel
            </Button>
            <Button type="submit" disabled={busy || !code.trim()}>
              {busy ? "Creating…" : "Create"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
