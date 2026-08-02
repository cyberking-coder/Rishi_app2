import { createClient } from "@/lib/supabase/server";
import { PageHeader } from "@/components/page-header";
import { SessionFormDialog } from "@/components/sessions/session-form-dialog";
import { SessionActions } from "@/components/sessions/session-actions";
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
import { formatDateTime } from "@/lib/utils";
import type { LiveSession, SessionReminder } from "@/lib/types";

export const dynamic = "force-dynamic";

export default async function SessionsPage() {
  const supabase = createClient();

  // Fetched flat and joined below rather than embedded. A PostgREST
  // embed that fails takes the whole select down with it, and the
  // reminder log is the least important column on the page — it must not
  // be able to blank the schedule.
  const [{ data: sessions }, { data: reminders }, { count: deviceCount }] =
    await Promise.all([
      supabase
        .from("live_sessions")
        .select("*")
        .order("starts_at", { ascending: false })
        .returns<LiveSession[]>(),
      supabase
        .from("session_reminders")
        .select("*")
        .returns<SessionReminder[]>(),
      supabase
        .from("push_tokens")
        .select("token", { count: "exact", head: true }),
    ]);

  const sentBySession = new Map<string, number[]>();
  for (const r of reminders ?? []) {
    const marks = sentBySession.get(r.session_id) ?? [];
    marks.push(r.minutes_before);
    sentBySession.set(r.session_id, marks);
  }

  const now = Date.now();

  return (
    <div>
      <PageHeader
        title="Live sessions"
        description="Zoom meetings shown in the app's Watch section. Members get a push notification an hour, 30 minutes and 5 minutes before one starts, and tap the card to join."
        action={<SessionFormDialog />}
      />

      <p className="mb-4 text-sm text-muted-foreground">
        {deviceCount ?? 0} device{deviceCount === 1 ? "" : "s"} registered for
        notifications.
        {(deviceCount ?? 0) === 0 &&
          " Nobody will be reminded until someone opens the app and allows notifications."}
      </p>

      <Card>
        <CardContent className="p-0">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead className="w-28">Thumbnail</TableHead>
                <TableHead>Title</TableHead>
                <TableHead>Starts</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Reminders sent</TableHead>
                <TableHead className="w-32" />
              </TableRow>
            </TableHeader>
            <TableBody>
              {(sessions ?? []).length === 0 ? (
                <TableRow>
                  <TableCell
                    colSpan={6}
                    className="py-8 text-center text-muted-foreground"
                  >
                    No sessions yet. Schedule one to show it in the app.
                  </TableCell>
                </TableRow>
              ) : (
                (sessions ?? []).map((s) => {
                  const sent = (sentBySession.get(s.id) ?? []).sort(
                    (a, b) => b - a,
                  );
                  const past =
                    new Date(s.starts_at).getTime() +
                      s.duration_minutes * 60_000 <
                    now;

                  return (
                    <TableRow key={s.id}>
                      <TableCell>
                        {s.thumbnail_url ? (
                          /* eslint-disable-next-line @next/next/no-img-element */
                          <img
                            src={s.thumbnail_url}
                            alt=""
                            className="h-12 w-20 rounded-md object-cover"
                          />
                        ) : (
                          <div className="h-12 w-20 rounded-md bg-muted" />
                        )}
                      </TableCell>
                      <TableCell className="font-medium">
                        <a
                          href={s.join_url}
                          target="_blank"
                          rel="noreferrer"
                          className="hover:underline"
                        >
                          {s.title}
                        </a>
                        <p className="text-xs font-normal text-muted-foreground">
                          {s.duration_minutes} min
                        </p>
                      </TableCell>
                      <TableCell className="text-muted-foreground">
                        {formatDateTime(s.starts_at)}
                      </TableCell>
                      <TableCell>
                        {s.status === "cancelled" ? (
                          <Badge variant="destructive">Cancelled</Badge>
                        ) : past ? (
                          <Badge variant="outline">Finished</Badge>
                        ) : (
                          <Badge variant="success">Scheduled</Badge>
                        )}
                      </TableCell>
                      <TableCell className="text-muted-foreground">
                        {sent.length === 0
                          ? "—"
                          : sent.map((m) => `${m}m`).join(", ")}
                      </TableCell>
                      <TableCell>
                        <SessionActions session={s} />
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
