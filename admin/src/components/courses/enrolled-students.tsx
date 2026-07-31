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
  status: "paid" | "revoked";
  /** Time-limited access that lapses on its own. null = permanent.
   *  Independent of `status`, which is what an admin withdrawal sets. */
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
      "user_id, amount, currency, discount_amount, created_at, status, expires_at",
    )
    .eq("course_id", courseId)
    // Withdrawn enrolments are 'revoked', not deleted — they belong on
    // the roster so the removal can be undone and the payment stays
    // visible.
    .in("status", ["paid", "revoked"])
    .order("created_at", { ascending: false })
    .returns<PurchaseRow[]>();

  const rows = purchases ?? [];

  // Payments taken for a course the buyer already owned. Deliberately
  // counted apart from the roster rather than folded into it: they
  // enrolled nobody, and the dedupe below keeps one row per student, so
  // a duplicate listed alongside would hide the real enrolment it
  // duplicates. Surfacing the count is what makes the refund owed
  // visible at all.
  const { count: duplicateCount } = await supabase
    .from("course_purchases")
    .select("id", { count: "exact", head: true })
    .eq("course_id", courseId)
    .eq("status", "duplicate");

  // One person can hold more than one row — a rebuy after being removed
  // leaves the revoked one behind — and they're one student either way.
  // Keep the earliest-listed, which is the most recent purchase given
  // the ordering above, so a student who rebought reads as active.
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
          {(duplicateCount ?? 0) > 0 && (
            <Badge
              variant="destructive"
              title="Paid for a course the buyer already owned — no access was granted and a refund is owed."
            >
              {duplicateCount} duplicate{duplicateCount === 1 ? "" : "s"} to refund
            </Badge>
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

/** No current access, whether an admin withdrew it or a time-limited
 *  enrolment simply ran out. */
function isRevoked(row: PurchaseRow): boolean {
  if (row.status === "revoked") return true;
  // A time-limited enrolment that has run out is equally "no access",
  // even though no admin touched it.
  return row.expires_at !== null && new Date(row.expires_at) <= new Date();
}

/** Amounts are stored in paise, the unit Razorpay charges in. */
function formatMoney(paise: number, currency = "INR"): string {
  const symbol = currency === "INR" ? "₹" : `${currency} `;
  const major = paise / 100;
  return `${symbol}${major % 1 === 0 ? major : major.toFixed(2)}`;
}
