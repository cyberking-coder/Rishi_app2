"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Power } from "lucide-react";
import { setPlanActive, type SubscriptionPlan } from "@/app/actions/plans";
import { Button } from "@/components/ui/button";

/// Retire / restore. There is deliberately no delete: subscriptions.plan_id
/// points here with no cascade, so a plan somebody bought has to stay
/// readable on their record forever.
export function PlanActions({ plan }: { plan: SubscriptionPlan }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);

  async function toggle() {
    setBusy(true);
    const result = await setPlanActive({
      planId: plan.id,
      isActive: !plan.is_active,
    });
    setBusy(false);

    if (!result.ok) return toast.error(result.error);
    toast.success(plan.is_active ? "Plan retired" : "Plan is on sale again");
    router.refresh();
  }

  return (
    <Button
      variant="ghost"
      size="sm"
      onClick={toggle}
      disabled={busy}
      className={plan.is_active ? "text-muted-foreground" : "text-primary"}
    >
      <Power className="h-4 w-4" />
      {plan.is_active ? "Retire" : "Restore"}
    </Button>
  );
}
