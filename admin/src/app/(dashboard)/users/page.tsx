import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { PageHeader } from "@/components/page-header";
import { CreateUserDialog } from "@/components/users/create-user-dialog";
import { ResetAllDevicesButton } from "@/components/users/reset-all-devices-button";
import { UserActions } from "@/components/users/user-actions";
import { UserStatusBadge } from "@/components/status-badge";
import { Badge } from "@/components/ui/badge";
import {
  Card,
  CardContent,
} from "@/components/ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { formatDate } from "@/lib/utils";
import { resolveTier } from "@/lib/access";
import type { Profile } from "@/lib/types";

export const dynamic = "force-dynamic";

export default async function UsersPage() {
  const supabase = createClient();
  const [{ data: users }, { data: purchases }] = await Promise.all([
    supabase
      .from("profiles")
      .select("*")
      .order("created_at", { ascending: false })
      .returns<Profile[]>(),
    // Courses are sold individually, so someone can be a paying customer
    // with no subscription at all. Without this the tier column reads
    // "Free" for a buyer, which is the same mistake the app's profile
    // header was making.
    supabase
      .from("course_purchases")
      .select("user_id, course_id")
      .eq("status", "paid")
      .returns<{ user_id: string; course_id: string }[]>(),
  ]);

  // Distinct courses per buyer — a rebuy after a refund leaves two paid
  // rows for the same course and shouldn't read as two courses owned.
  const coursesByUser = new Map<string, Set<string>>();
  for (const p of purchases ?? []) {
    const set = coursesByUser.get(p.user_id) ?? new Set<string>();
    set.add(p.course_id);
    coursesByUser.set(p.user_id, set);
  }

  // Email lives in auth.users, not profiles. Fetch it with the service-role
  // client so each row can be identified by email (display names are often
  // blank). Keyed by user id.
  const emailById = new Map<string, string>();
  try {
    const admin = createAdminClient();
    const { data: authList } = await admin.auth.admin.listUsers({
      page: 1,
      perPage: 1000,
    });
    for (const u of authList?.users ?? []) {
      if (u.email) emailById.set(u.id, u.email);
    }
  } catch {
    // If listing fails, fall back to showing display names only.
  }

  return (
    <div>
      <PageHeader
        title="Users"
        description="Manage accounts, roles, status, and device locks."
        action={
          <div className="flex items-center gap-2">
            <ResetAllDevicesButton />
            <CreateUserDialog />
          </div>
        }
      />

      <Card>
        <CardContent className="p-0">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Name</TableHead>
                <TableHead>Role</TableHead>
                <TableHead>Tier</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Access</TableHead>
                <TableHead>Joined</TableHead>
                <TableHead className="w-12" />
              </TableRow>
            </TableHeader>
            <TableBody>
              {(users ?? []).length === 0 ? (
                <TableRow>
                  <TableCell colSpan={7} className="py-8 text-center text-muted-foreground">
                    No users yet.
                  </TableCell>
                </TableRow>
              ) : (
                (users ?? []).map((u) => (
                  <TableRow key={u.id}>
                    <TableCell className="font-medium">
                      <div>{u.display_name ?? "—"}</div>
                      <div className="text-xs font-normal text-muted-foreground">
                        {emailById.get(u.id) ?? "—"}
                      </div>
                    </TableCell>
                    <TableCell>
                      <Badge variant="outline">{u.role}</Badge>
                    </TableCell>
                    <TableCell>
                      <TierCell
                        profile={u}
                        coursesOwned={coursesByUser.get(u.id)?.size ?? 0}
                      />
                    </TableCell>
                    <TableCell>
                      <UserStatusBadge status={u.status} />
                    </TableCell>
                    <TableCell>
                      <AccessCell
                        profile={u}
                        coursesOwned={coursesByUser.get(u.id)?.size ?? 0}
                      />
                    </TableCell>
                    <TableCell className="text-muted-foreground">
                      {formatDate(u.created_at)}
                    </TableCell>
                    <TableCell>
                      <UserActions userId={u.id} status={u.status} />
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </div>
  );
}

/** Derived from the access window rather than the denormalized
 *  `subscription_tier` column, so ending a user's access immediately shows
 *  them as Free. The column alone would keep reading "premium" until
 *  something happened to rewrite it. */
function TierCell({
  profile,
  coursesOwned,
}: {
  profile: Profile;
  coursesOwned: number;
}) {
  const tier = resolveTier(profile);
  if (tier === "admin") {
    return <Badge variant="outline">Staff</Badge>;
  }
  if (tier === "retreat") {
    return <Badge>Premium</Badge>;
  }
  // A course buyer is premium too, but for a different reason — the
  // tooltip says which, so "Premium" with no subscription in the Access
  // column doesn't look like a bug.
  if (coursesOwned > 0) {
    return (
      <Badge
        title={`Bought ${coursesOwned} course${coursesOwned === 1 ? "" : "s"}`}
      >
        Premium
      </Badge>
    );
  }
  return <Badge variant="outline">Free</Badge>;
}

/** Shows the user's resolved tier / remaining access window as a badge. */
function AccessCell({
  profile,
  coursesOwned,
}: {
  profile: Profile;
  coursesOwned: number;
}) {
  const tier = resolveTier(profile);

  if (tier === "free") {
    // No subscription window to report, but course access is real and
    // permanent — say so rather than flatly "Free".
    if (coursesOwned > 0) {
      return (
        <Badge variant="secondary">
          {coursesOwned} course{coursesOwned === 1 ? "" : "s"}
        </Badge>
      );
    }
    return <Badge variant="outline">Free</Badge>;
  }

  const expiresAt = profile.access_expires_at;
  if (!expiresAt) {
    return <Badge variant="outline">Unlimited</Badge>;
  }
  const ms = new Date(expiresAt).getTime() - Date.now();
  if (ms <= 0) {
    return <Badge variant="destructive">Expired</Badge>;
  }
  const days = Math.ceil(ms / (24 * 60 * 60 * 1000));
  return (
    <Badge variant={days <= 7 ? "secondary" : "outline"}>
      {days}d left
    </Badge>
  );
}
