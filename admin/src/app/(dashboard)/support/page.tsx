import { createClient } from "@/lib/supabase/server";
import { PageHeader } from "@/components/page-header";
import { TicketDialog } from "@/components/support/ticket-dialog";
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
import type { TicketStatus } from "@/app/actions/support";

export const dynamic = "force-dynamic";

interface TicketRow {
  id: string;
  reference: number;
  subject: string;
  category: string;
  status: TicketStatus;
  priority: string;
  user_id: string;
  created_at: string;
  updated_at: string;
}

const STATUS_LABEL: Record<TicketStatus, string> = {
  open: "Open",
  in_progress: "In progress",
  waiting_on_user: "Waiting on user",
  resolved: "Resolved",
};

// Open work stands out; resolved recedes.
function statusVariant(
  status: TicketStatus,
): "success" | "outline" | "default" {
  if (status === "resolved") return "outline";
  if (status === "open") return "default";
  return "success";
}

const ZERO_UUID = "00000000-0000-0000-0000-000000000000";

export default async function SupportPage() {
  const supabase = createClient();

  // Fetch tickets, then member names in a second query joined in code — the
  // same flat-fetch pattern the rest of this codebase uses, since one
  // failing PostgREST embed nulls the whole select.
  const { data: tickets } = await supabase
    .from("support_tickets")
    .select(
      "id, reference, subject, category, status, priority, user_id, created_at, updated_at",
    )
    .order("updated_at", { ascending: false })
    .returns<TicketRow[]>();

  const rows = tickets ?? [];
  const userIds = Array.from(new Set(rows.map((t) => t.user_id)));
  const { data: profiles } = await supabase
    .from("profiles")
    .select("id, display_name")
    .in("id", userIds.length ? userIds : [ZERO_UUID])
    .returns<Array<{ id: string; display_name: string | null }>>();
  const nameById = new Map(
    (profiles ?? []).map((p) => [p.id, p.display_name]),
  );

  const openCount = rows.filter((t) => t.status !== "resolved").length;

  return (
    <div>
      <PageHeader
        title="Help & Support"
        description={
          openCount > 0
            ? `${openCount} ticket${openCount === 1 ? "" : "s"} need a reply. Open one to read the conversation and respond.`
            : "Tickets members raise from the app. Open one to read the conversation and respond."
        }
      />

      <Card>
        <CardContent className="p-0">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Ref</TableHead>
                <TableHead>Subject</TableHead>
                <TableHead>Member</TableHead>
                <TableHead>Category</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Updated</TableHead>
                <TableHead className="w-16" />
              </TableRow>
            </TableHeader>
            <TableBody>
              {rows.length === 0 ? (
                <TableRow>
                  <TableCell
                    colSpan={7}
                    className="py-8 text-center text-muted-foreground"
                  >
                    No support tickets yet.
                  </TableCell>
                </TableRow>
              ) : (
                rows.map((t) => {
                  const memberName = nameById.get(t.user_id) ?? "Member";
                  return (
                    <TableRow key={t.id}>
                      <TableCell className="font-mono text-muted-foreground">
                        #{t.reference}
                      </TableCell>
                      <TableCell className="max-w-[22rem] truncate font-medium">
                        {t.subject}
                      </TableCell>
                      <TableCell className="text-muted-foreground">
                        {memberName}
                      </TableCell>
                      <TableCell className="capitalize text-muted-foreground">
                        {t.category}
                      </TableCell>
                      <TableCell>
                        <Badge variant={statusVariant(t.status)}>
                          {STATUS_LABEL[t.status]}
                        </Badge>
                      </TableCell>
                      <TableCell className="text-muted-foreground">
                        {formatDate(t.updated_at)}
                      </TableCell>
                      <TableCell>
                        <TicketDialog
                          ticketId={t.id}
                          reference={t.reference}
                          subject={t.subject}
                          memberName={memberName}
                          status={t.status}
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
