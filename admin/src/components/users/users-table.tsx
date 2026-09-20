"use client";

import { useMemo, useState } from "react";
import { Search } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { UserActions } from "@/components/users/user-actions";
import { UserStatusBadge } from "@/components/status-badge";
import { formatDate } from "@/lib/utils";
import { resolveTier } from "@/lib/access";
import type { Profile } from "@/lib/types";

export interface UserRow {
  profile: Profile;
  email: string | null;
  coursesOwned: number;
}

/** The Users table with a client-side search over name and email.
 *
 *  Search runs in the browser because the two fields it matches live in
 *  different places — the display name in `profiles`, the email in
 *  `auth.users` (fetched server-side and passed in) — so there is no single
 *  SQL query to filter both. The full list is already loaded, so filtering
 *  here is instant and needs no round-trip. */
export function UsersTable({ rows }: { rows: UserRow[] }) {
  const [query, setQuery] = useState("");

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return rows;
    return rows.filter(({ profile, email }) => {
      const name = (profile.display_name ?? "").toLowerCase();
      return name.includes(q) || (email ?? "").toLowerCase().includes(q);
    });
  }, [rows, query]);

  return (
    <div className="space-y-3">
      <div className="relative max-w-sm">
        <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
        <Input
          type="search"
          placeholder="Search by name or email…"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          className="pl-9"
          aria-label="Search users by name or email"
        />
      </div>

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
          {filtered.length === 0 ? (
            <TableRow>
              <TableCell
                colSpan={7}
                className="py-8 text-center text-muted-foreground"
              >
                {rows.length === 0
                  ? "No users yet."
                  : "No users match that search."}
              </TableCell>
            </TableRow>
          ) : (
            filtered.map(({ profile: u, email, coursesOwned }) => (
              <TableRow key={u.id}>
                <TableCell className="font-medium">
                  <div>{u.display_name ?? "—"}</div>
                  <div className="text-xs font-normal text-muted-foreground">
                    {email ?? "—"}
                  </div>
                </TableCell>
                <TableCell>
                  <Badge variant="outline">{u.role}</Badge>
                </TableCell>
                <TableCell>
                  <TierCell profile={u} coursesOwned={coursesOwned} />
                </TableCell>
                <TableCell>
                  <UserStatusBadge status={u.status} />
                </TableCell>
                <TableCell>
                  <AccessCell profile={u} coursesOwned={coursesOwned} />
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
    </div>
  );
}

/** Derived from the access window rather than the denormalized
 *  `subscription_tier` column, so ending a user's access immediately shows
 *  them as Free. */
function TierCell({
  profile,
  coursesOwned,
}: {
  profile: Profile;
  coursesOwned: number;
}) {
  const tier = resolveTier(profile);
  if (tier === "admin") return <Badge variant="outline">Staff</Badge>;
  if (tier === "retreat") return <Badge>Premium</Badge>;
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
  if (!expiresAt) return <Badge variant="outline">Unlimited</Badge>;
  const ms = new Date(expiresAt).getTime() - Date.now();
  if (ms <= 0) return <Badge variant="destructive">Expired</Badge>;
  const days = Math.ceil(ms / (24 * 60 * 60 * 1000));
  return (
    <Badge variant={days <= 7 ? "secondary" : "outline"}>{days}d left</Badge>
  );
}
