import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { PageHeader } from "@/components/page-header";
import { CreateUserDialog } from "@/components/users/create-user-dialog";
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
import type { Profile } from "@/lib/types";

export const dynamic = "force-dynamic";

export default async function UsersPage() {
  const supabase = createClient();
  const { data: users } = await supabase
    .from("profiles")
    .select("*")
    .order("created_at", { ascending: false })
    .returns<Profile[]>();

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
        action={<CreateUserDialog />}
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
                    <TableCell className="capitalize">{u.subscription_tier}</TableCell>
                    <TableCell>
                      <UserStatusBadge status={u.status} />
                    </TableCell>
                    <TableCell>
                      <AccessCell expiresAt={u.access_expires_at} />
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

/** Shows the user's remaining access window as a coloured badge. */
function AccessCell({ expiresAt }: { expiresAt: string | null }) {
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
