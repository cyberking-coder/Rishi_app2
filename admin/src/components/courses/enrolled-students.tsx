import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { formatDate } from "@/lib/utils";
import { EnrolmentAccessButton } from "./enrolment-access-button";

interface PurchaseRow {
  user_id: string;
  amount: number;
  currency: string;
  discount_amount: number | null;
  created_at: string;
  /** Past timestamp = access revoked. null = permanent. */
  expires_at: string | null;
}

/**
 * Who is actually in this course — everyone with a paid purchase.
 *
 * Deliberately not "everyone with access": a staff account or an admin
 * grant can open a course without buying it, and mixing those in would
 * make this list disagree with revenue. Paid rows only.
 */
export async function EnrolledStudents({ courseId }: { courseId: string }) {
  const supabase = createClient();

  const { data: purchases } = await supabase
    .from("course_purchases")
    .select(
      "user_id, amount, currency, discount_amount, created_at, expires_at",
    )
    .eq("course_id", courseId)
    .eq("status", "paid")
    .order("created_at", { ascending: false })
    .returns<PurchaseRow[]>();

  const rows = purchases ?? [];

  // One person can hold more than one paid row (a rebuy after a refund),
  // and they're one student either way. Keep the earliest-listed row,
  // which is the most recent purchase given the ordering above.
  const seen = new Set<string>();
  const unique = rows.filter((r) => {
    if (seen.has(r.user_id)) return false;
    seen.add(r.user_id);
    return true;
  });

  const nameById = new Map<string, string>();
  const emailById = new Map<string, string>();

  if (unique.length > 0) {
    const ids = unique.map((r) => r.user_id);
    const { data: profiles } = await supabase
      .from("profiles")
      .select("id, display_name")
      .in("id", ids)
      .returns<{ id: string; display_name: string | null }[]>();
    for (const p of profiles ?? []) {
      if (p.display_name) nameById.set(p.id, p.display_name);
    }

    // Email lives in auth.users, so it needs the service-role client.
    // Best-effort: without it the list still identifies people by name.
    try {
      const admin = createAdminClient();
      const { data: authList } = await admin.auth.admin.listUsers({
        page: 1,
        perPage: 1000,
      });
      for (const u of authList?.users ?? []) {
        if (u.email && seen.has(u.id)) emailById.set(u.id, u.email);
      }
    } catch {
      // ignore
    }
  }

  // Revenue counts revoked enrolments too — the money was received, and
  // a total that silently shrank when access was withdrawn would stop
  // matching what Razorpay settled.
  const revenue = unique.reduce((sum, r) => sum + r.amount, 0);
  const active = unique.filter((r) => !isRevoked(r)).length;

  return (
    <Card className="mt-6">
      <CardHeader className="flex-row items-center justify-between space-y-0">
        <CardTitle>Enrolled students</CardTitle>
        <div className="flex items-center gap-2">
          <Badge variant="outline">
            {active} {active === 1 ? "student" : "students"}
          </Badge>
          {active !== unique.length && (
            <Badge variant="secondary">
              {unique.length - active} revoked
            </Badge>
          )}
          {revenue > 0 && (
            <Badge variant="success">{formatMoney(revenue)} collected</Badge>
          )}
        </div>
      </CardHeader>
      <CardContent className="p-0">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Student</TableHead>
              <TableHead>Paid</TableHead>
              <TableHead>Enrolled</TableHead>
              <TableHead>Access</TableHead>
              <TableHead className="w-32" />
            </TableRow>
          </TableHeader>
          <TableBody>
            {unique.length === 0 ? (
              <TableRow>
                <TableCell
                  colSpan={5}
                  className="py-8 text-center text-muted-foreground"
                >
                  Nobody has bought this course yet.
                </TableCell>
              </TableRow>
            ) : (
              unique.map((r) => (
                <TableRow key={r.user_id}>
                  <TableCell className="font-medium">
                    <div>{nameById.get(r.user_id) ?? "—"}</div>
                    <div className="text-xs font-normal text-muted-foreground">
                      {emailById.get(r.user_id) ?? "—"}
                    </div>
                  </TableCell>
                  <TableCell>
                    {formatMoney(r.amount, r.currency)}
                    {r.discount_amount ? (
                      <span className="ml-1.5 text-xs text-muted-foreground">
                        (−{formatMoney(r.discount_amount, r.currency)} coupon)
                      </span>
                    ) : null}
                  </TableCell>
                  <TableCell className="text-muted-foreground">
                    {formatDate(r.created_at)}
                  </TableCell>
                  <TableCell>
                    {isRevoked(r) ? (
                      <Badge variant="destructive">Revoked</Badge>
                    ) : (
                      <Badge variant="success">Active</Badge>
                    )}
                  </TableCell>
                  <TableCell className="text-right">
                    <EnrolmentAccessButton
                      userId={r.user_id}
                      courseId={courseId}
                      studentLabel={
                        nameById.get(r.user_id) ??
                        emailById.get(r.user_id) ??
                        "this student"
                      }
                      revoked={isRevoked(r)}
                    />
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  );
}

/** Access is withdrawn by dating `expires_at` in the past rather than
 *  by changing `status`, so the sale stays on the books. */
function isRevoked(row: PurchaseRow): boolean {
  return row.expires_at !== null && new Date(row.expires_at) <= new Date();
}

/** Amounts are stored in paise, the unit Razorpay charges in. */
function formatMoney(paise: number, currency = "INR"): string {
  const symbol = currency === "INR" ? "₹" : `${currency} `;
  const major = paise / 100;
  return `${symbol}${major % 1 === 0 ? major : major.toFixed(2)}`;
}
