import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { PageHeader } from "@/components/page-header";
import { CreateUserDialog } from "@/components/users/create-user-dialog";
import { ResetAllDevicesButton } from "@/components/users/reset-all-devices-button";
import { UsersTable, type UserRow } from "@/components/users/users-table";
import { Card, CardContent } from "@/components/ui/card";
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
      // An enrolment revoked from the course page is dated in the past
      // rather than deleted. Without this filter the user would go on
      // reading as Premium after their access was taken away — which is
      // exactly the disagreement between the two pages worth avoiding.
      .or(`expires_at.is.null,expires_at.gt.${new Date().toISOString()}`)
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

  // Flatten into serializable rows the client table can search and render.
  const rows: UserRow[] = (users ?? []).map((u) => ({
    profile: u,
    email: emailById.get(u.id) ?? null,
    coursesOwned: coursesByUser.get(u.id)?.size ?? 0,
  }));

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
        <CardContent className="p-4">
          <UsersTable rows={rows} />
        </CardContent>
      </Card>
    </div>
  );
}
