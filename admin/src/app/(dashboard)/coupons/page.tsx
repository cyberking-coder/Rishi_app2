import { createClient } from "@/lib/supabase/server";
import { PageHeader } from "@/components/page-header";
import { CreateCouponDialog } from "@/components/coupons/create-coupon-dialog";
import { CouponActions } from "@/components/coupons/coupon-actions";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent } from "@/components/ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { formatDate } from "@/lib/utils";
import type { Coupon, Course } from "@/lib/types";

export const dynamic = "force-dynamic";

function discountLabel(c: Coupon): string {
  return c.discount_type === "percent"
    ? `${c.discount_value}% off`
    : `₹${c.discount_value / 100} off`;
}

/** Why a coupon can't currently be redeemed, or null if it can. */
function inactiveReason(c: Coupon): string | null {
  if (!c.is_active) return "Disabled";
  if (c.expires_at && new Date(c.expires_at) <= new Date()) return "Expired";
  if (c.max_redemptions !== null && c.times_redeemed >= c.max_redemptions) {
    return "Used up";
  }
  return null;
}

export default async function CouponsPage() {
  const supabase = createClient();

  const [{ data: coupons }, { data: courses }, { data: plans }] =
    await Promise.all([
    supabase
      .from("coupons")
      .select("*")
      .order("created_at", { ascending: false })
      .returns<Coupon[]>(),
    supabase
      .from("courses")
      .select("id, title")
      .order("title", { ascending: true })
      .returns<Pick<Course, "id" | "title">[]>(),
    supabase
      .from("subscription_plans")
      .select("id, name")
      .order("name", { ascending: true })
      .returns<{ id: string; name: string }[]>(),
  ]);

  const courseTitleById = new Map(
    (courses ?? []).map((c) => [c.id, c.title]),
  );
  const planNameById = new Map((plans ?? []).map((p) => [p.id, p.name]));

  /// What a code can be spent on, in one phrase.
  function scopeLabel(c: Coupon): string {
    if (c.applies_to === "any") return "Everything";
    if (c.applies_to === "subscription") {
      return c.plan_id
        ? (planNameById.get(c.plan_id) ?? "One plan")
        : "Membership";
    }
    return c.course_id
      ? (courseTitleById.get(c.course_id) ?? "One course")
      : "All courses";
  }

  return (
    <div>
      <PageHeader
        title="Coupons"
        description="Discount codes buyers can enter at checkout, for courses or for the membership."
        action={
          <CreateCouponDialog courses={courses ?? []} plans={plans ?? []} />
        }
      />

      <Card>
        <CardContent className="p-0">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Code</TableHead>
                <TableHead>Discount</TableHead>
                <TableHead>Applies to</TableHead>
                <TableHead>Used</TableHead>
                <TableHead>Expires</TableHead>
                <TableHead>Status</TableHead>
                <TableHead className="w-12" />
              </TableRow>
            </TableHeader>
            <TableBody>
              {(coupons ?? []).length === 0 ? (
                <TableRow>
                  <TableCell
                    colSpan={7}
                    className="py-8 text-center text-muted-foreground"
                  >
                    No coupons yet.
                  </TableCell>
                </TableRow>
              ) : (
                (coupons ?? []).map((c) => {
                  const reason = inactiveReason(c);
                  return (
                    <TableRow key={c.id}>
                      <TableCell className="font-mono font-medium">
                        {c.code}
                      </TableCell>
                      <TableCell>{discountLabel(c)}</TableCell>
                      <TableCell className="text-muted-foreground">
                        {scopeLabel(c)}
                      </TableCell>
                      <TableCell>
                        {c.times_redeemed}
                        {c.max_redemptions !== null && ` / ${c.max_redemptions}`}
                      </TableCell>
                      <TableCell className="text-muted-foreground">
                        {c.expires_at ? formatDate(c.expires_at) : "—"}
                      </TableCell>
                      <TableCell>
                        <Badge variant={reason ? "outline" : "success"}>
                          {reason ?? "Active"}
                        </Badge>
                      </TableCell>
                      <TableCell>
                        <CouponActions
                          couponId={c.id}
                          isActive={c.is_active}
                        />
                      </TableCell>
                    </TableRow>
                  );
                })
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </div>
  );
}
