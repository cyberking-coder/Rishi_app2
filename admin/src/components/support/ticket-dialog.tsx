"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import { NativeSelect, NativeOption } from "@/components/ui/native-select";
import {
  getTicketThread,
  replyToTicket,
  setTicketStatus,
  type SupportMessageView,
  type TicketStatus,
} from "@/app/actions/support";

const STATUS_LABEL: Record<TicketStatus, string> = {
  open: "Open",
  in_progress: "In progress",
  waiting_on_user: "Waiting on user",
  resolved: "Resolved",
};

function fmt(iso: string): string {
  return new Date(iso).toLocaleString("en-IN", {
    day: "numeric",
    month: "short",
    hour: "numeric",
    minute: "2-digit",
  });
}

export function TicketDialog({
  ticketId,
  reference,
  subject,
  memberName,
  status,
}: {
  ticketId: string;
  reference: number;
  subject: string;
  memberName: string;
  status: TicketStatus;
}) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [messages, setMessages] = useState<SupportMessageView[]>([]);
  const [memberEmail, setMemberEmail] = useState<string | null>(null);
  const [reply, setReply] = useState("");
  const [internal, setInternal] = useState(false);
  const [busy, setBusy] = useState(false);

  async function load() {
    setLoading(true);
    const result = await getTicketThread(ticketId);
    setLoading(false);
    if (!result.ok) {
      toast.error(result.error);
      return;
    }
    setMessages(result.messages);
    setMemberEmail(result.memberEmail);
  }

  function onOpenChange(next: boolean) {
    setOpen(next);
    if (next) load();
  }

  async function send() {
    if (!reply.trim()) return;
    setBusy(true);
    const result = await replyToTicket({
      ticketId,
      body: reply,
      isInternal: internal,
    });
    setBusy(false);
    if (!result.ok) {
      toast.error(result.error);
      return;
    }
    setReply("");
    toast.success(internal ? "Internal note saved" : "Reply sent");
    await load();
    router.refresh();
  }

  async function changeStatus(next: TicketStatus) {
    const result = await setTicketStatus({ ticketId, status: next });
    if (!result.ok) {
      toast.error(result.error);
      return;
    }
    toast.success(`Marked ${STATUS_LABEL[next].toLowerCase()}`);
    router.refresh();
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogTrigger asChild>
        <Button variant="outline" size="sm">
          Open
        </Button>
      </DialogTrigger>
      <DialogContent className="max-w-2xl">
        <DialogHeader>
          <DialogTitle>
            #{reference} · {subject}
          </DialogTitle>
          <DialogDescription>
            {memberName}
            {memberEmail ? ` · ${memberEmail}` : ""}
          </DialogDescription>
        </DialogHeader>

        {/* Status control */}
        <div className="flex items-center gap-2">
          <span className="text-sm text-muted-foreground">Status</span>
          <div className="w-48">
            <NativeSelect
              defaultValue={status}
              onChange={(e) => changeStatus(e.target.value as TicketStatus)}
            >
              {(Object.keys(STATUS_LABEL) as TicketStatus[]).map((s) => (
                <NativeOption key={s} value={s}>
                  {STATUS_LABEL[s]}
                </NativeOption>
              ))}
            </NativeSelect>
          </div>
        </div>

        {/* Conversation */}
        <div className="max-h-[45vh] space-y-3 overflow-y-auto rounded-md border p-3">
          {loading ? (
            <p className="py-6 text-center text-sm text-muted-foreground">
              Loading conversation…
            </p>
          ) : messages.length === 0 ? (
            <p className="py-6 text-center text-sm text-muted-foreground">
              No messages on this ticket.
            </p>
          ) : (
            messages.map((m) => (
              <div
                key={m.id}
                className={
                  m.from_staff ? "flex flex-col items-end" : "flex flex-col items-start"
                }
              >
                <div
                  className={[
                    "max-w-[85%] rounded-lg px-3 py-2 text-sm",
                    m.is_internal
                      ? "bg-amber-100 text-amber-950 ring-1 ring-amber-300"
                      : m.from_staff
                        ? "bg-primary text-primary-foreground"
                        : "bg-muted text-foreground",
                  ].join(" ")}
                >
                  {m.is_internal ? (
                    <span className="mb-1 block text-[10px] font-semibold uppercase tracking-wide">
                      Internal note
                    </span>
                  ) : null}
                  <span className="whitespace-pre-wrap">{m.body}</span>
                </div>
                <span className="mt-0.5 text-[11px] text-muted-foreground">
                  {m.from_staff ? (m.sender_name ?? "Support") : memberName} ·{" "}
                  {fmt(m.created_at)}
                </span>
              </div>
            ))
          )}
        </div>

        {/* Reply box */}
        <div className="space-y-2">
          <Textarea
            value={reply}
            onChange={(e) => setReply(e.target.value)}
            placeholder={
              internal
                ? "Write a private note (the member never sees this)…"
                : "Write a reply to the member…"
            }
            rows={3}
          />
          <div className="flex items-center justify-between">
            <label className="flex items-center gap-2 text-sm text-muted-foreground">
              <input
                type="checkbox"
                checked={internal}
                onChange={(e) => setInternal(e.target.checked)}
                className="h-4 w-4 accent-primary"
              />
              Internal note {internal ? <Badge variant="outline">private</Badge> : null}
            </label>
            <Button onClick={send} disabled={busy || !reply.trim()}>
              {busy ? "Sending…" : internal ? "Save note" : "Send reply"}
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}
