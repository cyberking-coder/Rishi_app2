"use server";

import { revalidatePath } from "next/cache";
import { requireAdmin } from "@/lib/auth";
import { createAdminClient } from "@/lib/supabase/admin";

export type ActionResult = { ok: true } | { ok: false; error: string };

export type TicketStatus =
  | "open"
  | "in_progress"
  | "waiting_on_user"
  | "resolved";

export interface SupportMessageView {
  id: string;
  body: string;
  from_staff: boolean;
  is_internal: boolean;
  created_at: string;
  sender_name: string | null;
}

const ZERO_UUID = "00000000-0000-0000-0000-000000000000";

/**
 * Loads the full conversation on a ticket, plus the member's email.
 *
 * Admin-only, through the service-role client, so it also returns internal
 * staff notes — those are hidden from the member by RLS in the app, but the
 * dashboard is exactly where they are meant to be read. Sender names are
 * resolved from profiles in a second query and joined in code rather than
 * embedded, matching the rest of this codebase (one failing PostgREST embed
 * nulls the whole select).
 */
export async function getTicketThread(ticketId: string): Promise<
  | { ok: true; messages: SupportMessageView[]; memberEmail: string | null }
  | { ok: false; error: string }
> {
  await requireAdmin();
  const db = createAdminClient();

  const { data: ticket, error: ticketError } = await db
    .from("support_tickets")
    .select("user_id")
    .eq("id", ticketId)
    .maybeSingle<{ user_id: string }>();
  if (ticketError) return { ok: false, error: ticketError.message };
  if (!ticket) return { ok: false, error: "Ticket not found" };

  const { data: rows, error } = await db
    .from("support_messages")
    .select("id, body, from_staff, is_internal, created_at, sender_id")
    .eq("ticket_id", ticketId)
    .order("created_at", { ascending: true })
    .returns<
      Array<{
        id: string;
        body: string;
        from_staff: boolean;
        is_internal: boolean;
        created_at: string;
        sender_id: string;
      }>
    >();
  if (error) return { ok: false, error: error.message };

  const senderIds = [...new Set((rows ?? []).map((r) => r.sender_id))];
  const { data: profiles } = await db
    .from("profiles")
    .select("id, display_name")
    .in("id", senderIds.length ? senderIds : [ZERO_UUID])
    .returns<Array<{ id: string; display_name: string | null }>>();
  const nameById = new Map(
    (profiles ?? []).map((p) => [p.id, p.display_name]),
  );

  let memberEmail: string | null = null;
  try {
    const { data: authUser } = await db.auth.admin.getUserById(ticket.user_id);
    memberEmail = authUser.user?.email ?? null;
  } catch {
    // Non-fatal — the thread is still readable without the email.
  }

  const messages: SupportMessageView[] = (rows ?? []).map((r) => ({
    id: r.id,
    body: r.body,
    from_staff: r.from_staff,
    is_internal: r.is_internal,
    created_at: r.created_at,
    sender_name: nameById.get(r.sender_id) ?? null,
  }));

  return { ok: true, messages, memberEmail };
}

/**
 * Posts a staff reply (or, with isInternal, a private note the member never
 * sees). sender_id is the acting admin's own id, which is what the
 * from_staff insert policy requires and what makes the "who answered this"
 * name resolvable.
 */
export async function replyToTicket(args: {
  ticketId: string;
  body: string;
  isInternal: boolean;
}): Promise<ActionResult> {
  const admin = await requireAdmin();
  const body = args.body.trim();
  if (!body) return { ok: false, error: "Message is empty" };

  const db = createAdminClient();
  const { error } = await db.from("support_messages").insert({
    ticket_id: args.ticketId,
    sender_id: admin.id,
    from_staff: true,
    is_internal: args.isInternal,
    body,
  });
  if (error) return { ok: false, error: error.message };

  // A public reply is an answer, so a still-open or waiting-on-user ticket
  // becomes "in progress". An internal note is invisible to the member and
  // changes nothing they perceive, so it leaves the status alone.
  if (!args.isInternal) {
    await db
      .from("support_tickets")
      .update({ status: "in_progress" })
      .eq("id", args.ticketId)
      .in("status", ["open", "waiting_on_user"]);
  }

  revalidatePath("/support");
  return { ok: true };
}

/** Sets a ticket's status. Stamps resolved_at on resolve and clears it on
 *  reopen, so the two never disagree. */
export async function setTicketStatus(args: {
  ticketId: string;
  status: TicketStatus;
}): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  const { error } = await db
    .from("support_tickets")
    .update({
      status: args.status,
      resolved_at: args.status === "resolved" ? new Date().toISOString() : null,
    })
    .eq("id", args.ticketId);
  if (error) return { ok: false, error: error.message };

  revalidatePath("/support");
  return { ok: true };
}
