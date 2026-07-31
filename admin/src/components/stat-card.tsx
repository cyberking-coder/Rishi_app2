import { Card, CardContent } from "@/components/ui/card";
import { cn } from "@/lib/utils";
import type { LucideIcon } from "lucide-react";

/**
 * Big-number tile. The value leads and the label sits beneath it, so a
 * row of these scans as figures first — the inverse of the usual
 * label-on-top card, and what makes the reference layout readable at a
 * glance.
 */
export function StatCard({
  title,
  value,
  icon: Icon,
  hint,
  className,
}: {
  title: string;
  value: string | number;
  icon?: LucideIcon;
  hint?: string;
  className?: string;
}) {
  return (
    <Card className={cn(className)}>
      <CardContent className="p-5">
        {Icon ? (
          <div className="mb-3 flex h-8 w-8 items-center justify-center rounded-full bg-accent">
            <Icon className="h-4 w-4 text-accent-foreground" />
          </div>
        ) : null}
        <div className="text-2xl font-semibold tracking-tight">{value}</div>
        <p className="mt-0.5 text-sm text-muted-foreground">{title}</p>
        {hint ? (
          <p className="mt-1 text-xs text-muted-foreground/80">{hint}</p>
        ) : null}
      </CardContent>
    </Card>
  );
}
