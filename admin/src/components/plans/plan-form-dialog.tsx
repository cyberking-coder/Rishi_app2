"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Pencil, Plus } from "lucide-react";
import { savePlan, type SubscriptionPlan } from "@/app/actions/plans";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { NativeOption, NativeSelect } from "@/components/ui/native-select";
import { Textarea } from "@/components/ui/textarea";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";

const INTERVALS = [
  { value: "weekly", label: "Weekly" },
  { value: "monthly", label: "Monthly" },
  { value: "yearly", label: "Yearly" },
] as const;

export function PlanFormDialog({ plan }: { plan?: SubscriptionPlan }) {
  const router = useRouter();
  const editing = Boolean(plan);

  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);

  const [name, setName] = useState(plan?.name ?? "");
  const [description, setDescription] = useState(plan?.description ?? "");
  // Kept as a string while typing so the box can be cleared — a number
  // state snaps an empty field back to 0 on every keystroke.
  const [price, setPrice] = useState(plan ? String(plan.price) : "");
  const [interval, setInterval] = useState<string>(
    plan?.billing_interval ?? "monthly",
  );
  const [isActive, setIsActive] = useState(plan?.is_active ?? true);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();

    const rupees = Number(price);
    if (!Number.isFinite(rupees) || rupees < 1) {
      return toast.error("Enter a price of at least ₹1.");
    }

    setBusy(true);
    const result = await savePlan({
      id: plan?.id,
      name,
      description: description || null,
      price: rupees,
      billingInterval: interval as "weekly" | "monthly" | "yearly",
      isActive,
    });
    setBusy(false);

    if (!result.ok) return toast.error(result.error);
    toast.success(editing ? "Plan updated" : "Plan created");
    setOpen(false);
    router.refresh();
  }

  return (
    <Dialog
      open={open}
      onOpenChange={(o) => {
        if (!busy) setOpen(o);
      }}
    >
      <DialogTrigger asChild>
        {editing ? (
          <Button variant="ghost" size="sm">
            <Pencil className="h-4 w-4" />
            Edit
          </Button>
        ) : (
          <Button>
            <Plus className="h-4 w-4" />
            New plan
          </Button>
        )}
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{editing ? "Edit plan" : "New plan"}</DialogTitle>
          <DialogDescription>
            The membership the app offers under &ldquo;Get Access
            Now&rdquo;. Only active plans are sold, and the cheapest
            active one is what the app shows.
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={onSubmit} className="space-y-4">
          <div>
            <Label htmlFor="plan-name">Name</Label>
            <Input
              id="plan-name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Rishi Mode"
              disabled={busy}
            />
          </div>

          <div>
            <Label htmlFor="plan-desc">Description</Label>
            <Textarea
              id="plan-desc"
              rows={3}
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="What the membership includes…"
              disabled={busy}
            />
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <Label htmlFor="plan-price">Price (₹)</Label>
              <Input
                id="plan-price"
                type="number"
                min={1}
                step="1"
                inputMode="decimal"
                value={price}
                onChange={(e) => setPrice(e.target.value)}
                placeholder="999"
                disabled={busy}
              />
            </div>
            <div>
              <Label htmlFor="plan-interval">Billing</Label>
              <NativeSelect
                id="plan-interval"
                value={interval}
                onChange={(e) => setInterval(e.target.value)}
                disabled={busy}
              >
                {INTERVALS.map((i) => (
                  <NativeOption key={i.value} value={i.value}>
                    {i.label}
                  </NativeOption>
                ))}
              </NativeSelect>
            </div>
          </div>

          <p className="text-xs text-muted-foreground">
            Changing a price only affects payments made from now on. Anyone
            already inside their access window keeps what they paid for
            until it ends.
          </p>

          <div className="flex items-center gap-2">
            <input
              id="plan-active"
              type="checkbox"
              checked={isActive}
              onChange={(e) => setIsActive(e.target.checked)}
              className="h-4 w-4 accent-primary"
              disabled={busy}
            />
            <Label htmlFor="plan-active">Available for purchase</Label>
          </div>

          <Button type="submit" disabled={busy}>
            {busy ? "Saving…" : editing ? "Save changes" : "Create plan"}
          </Button>
        </form>
      </DialogContent>
    </Dialog>
  );
}
