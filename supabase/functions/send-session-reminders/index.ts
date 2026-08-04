// Edge Function: send-session-reminders
//
// Polled by n8n every few minutes. Asks the database which live sessions
// have crossed a 60/30/5-minute mark without a reminder having gone out,
// and pushes one notification per mark.
//
// The function is a fan-out, not a scheduler: all the timing logic lives
// in due_session_reminders(), so "when does a reminder fire" has one
// answer in one place and this file only has to deliver.
//
// Deliveries are resumable. A reminder is claimed before it is sent (so
// two overlapping runs can't both notify everybody), and the claim
// carries how far the send got — an audience too large for one
// invocation is finished by the next run rather than half-delivered and
// marked done.
//
// Caller must present the service-role key. verify_jwt is left ON for
// this function (it accepts any valid project JWT), so the role check
// below is what actually restricts it — without it, any signed-in user
// could trigger a fan-out.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { handlePreflight, jsonResponse } from "../_shared/cors.ts";
import { FcmConfigError, type PushMessage } from "../_shared/fcm.ts";
import { fanOut, roleFromAuthHeader } from "../_shared/push_audience.ts";

interface DueReminder {
  session_id: string;
  title: string;
  starts_at: string;
  join_url: string;
  minutes_before: number;
}

interface OpenClaim {
  session_id: string;
  minutes_before: number;
  delivery_cursor: string | null;
  recipient_count: number;
  payload: PushMessage | null;
}

/// "in an hour" / "in 30 minutes" / "in 5 minutes". Written out rather
/// than templated from the number so the 60 case doesn't read as "in 60
/// minutes", which nobody says.
function whenPhrase(minutes: number): string {
  if (minutes >= 60) return "in an hour";
  return `in ${minutes} minutes`;
}

function messageFor(reminder: DueReminder): PushMessage {
  return {
    title: reminder.title,
    body: `Starts ${whenPhrase(reminder.minutes_before)}. ` +
      `Open the app and tap to join.`,
    data: {
      type: "live_session",
      session_id: reminder.session_id,
      join_url: reminder.join_url,
      deep_link: "/watch",
    },
    channelId: "session_reminders",
  };
}

Deno.serve(async (req) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  if (roleFromAuthHeader(req.headers.get("Authorization")) !== "service_role") {
    return jsonResponse({ error: "Service role required" }, 403);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const outcomes: Record<string, unknown>[] = [];

  // Unfinished deliveries first. They are already claimed, so
  // due_session_reminders() will never surface them again — if this pass
  // didn't exist, a reminder interrupted by the wall clock would sit
  // half-delivered forever.
  const { data: open } = await supabase
    .from("session_reminders")
    .select("session_id, minutes_before, delivery_cursor, recipient_count, payload")
    .is("completed_at", null)
    .order("sent_at", { ascending: true })
    .returns<OpenClaim[]>();

  for (const claim of open ?? []) {
    if (!claim.payload) {
      // Claimed before payloads were stored. Nothing can reconstruct what
      // it was meant to say, and guessing is worse than closing it.
      await markComplete(supabase, claim.session_id, claim.minutes_before);
      continue;
    }
    outcomes.push(
      await deliver(supabase, claim.payload, {
        sessionId: claim.session_id,
        minutesBefore: claim.minutes_before,
        startCursor: claim.delivery_cursor,
        alreadySent: claim.recipient_count,
        label: `${claim.payload.title} (resumed)`,
      }),
    );
  }

  const { data: due, error: dueError } = await supabase
    .rpc("due_session_reminders", { p_window_minutes: 10 })
    .returns<DueReminder[]>();

  if (dueError) {
    console.error(`due_session_reminders failed: ${dueError.message}`);
    return jsonResponse({ error: dueError.message }, 500);
  }

  for (const reminder of due ?? []) {
    const payload = messageFor(reminder);

    // Claim BEFORE sending. Two overlapping cron runs both see the same
    // due row, and the unique constraint is what makes only one of them
    // send. Claiming afterwards would let both through and double-notify
    // everyone — the same mistake the payment webhook made, in reverse.
    const { error: claimError } = await supabase
      .from("session_reminders")
      .insert({
        session_id: reminder.session_id,
        minutes_before: reminder.minutes_before,
        recipient_count: 0,
        payload,
      });

    if (claimError) {
      // 23505 = another run got there first. Not an error worth raising.
      if (claimError.code === "23505") {
        outcomes.push({
          session: reminder.title,
          minutes_before: reminder.minutes_before,
          skipped: "already claimed by a concurrent run",
        });
        continue;
      }
      console.error(`Could not claim reminder: ${claimError.message}`);
      outcomes.push({
        session: reminder.title,
        minutes_before: reminder.minutes_before,
        error: claimError.message,
      });
      continue;
    }

    outcomes.push(
      await deliver(supabase, payload, {
        sessionId: reminder.session_id,
        minutesBefore: reminder.minutes_before,
        startCursor: null,
        alreadySent: 0,
        label: reminder.title,
      }),
    );
  }

  return jsonResponse({
    ok: true,
    due: (due ?? []).length,
    resumed: (open ?? []).length,
    outcomes,
  });
});

async function deliver(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  payload: PushMessage,
  args: {
    sessionId: string;
    minutesBefore: number;
    startCursor: string | null;
    alreadySent: number;
    label: string;
  },
): Promise<Record<string, unknown>> {
  try {
    // Who this is addressed to, decided per reminder rather than carried
    // on the claim. A free session's reminder IS the invitation and goes
    // to everybody; a paid one goes to the people holding a seat, since
    // telling the rest that something starts in an hour is telling them
    // about a door they cannot open.
    //
    // Looked up here rather than passed in, so the resume path — which
    // reloads a claim, not a due row — narrows exactly the same way.
    const { data: session } = await supabase
      .from("live_sessions")
      .select("price_amount")
      .eq("id", args.sessionId)
      .maybeSingle();

    const paid = (session?.price_amount ?? 0) > 0;

    const result = await fanOut(supabase, payload, {
      startCursor: args.startCursor,
      sessionId: paid ? args.sessionId : null,
      onProgress: async (cursor, sentSoFar) => {
        await supabase
          .from("session_reminders")
          .update({
            delivery_cursor: cursor,
            recipient_count: args.alreadySent + sentSoFar,
          })
          .eq("session_id", args.sessionId)
          .eq("minutes_before", args.minutesBefore);
      },
    });

    await supabase
      .from("session_reminders")
      .update({
        delivery_cursor: result.cursor,
        recipient_count: args.alreadySent + result.sent,
        completed_at: result.complete ? new Date().toISOString() : null,
      })
      .eq("session_id", args.sessionId)
      .eq("minutes_before", args.minutesBefore);

    console.log(
      `Reminder "${args.label}" ${args.minutesBefore}m — ` +
        `${paid ? "registrants only" : "everyone"}, ` +
        `${result.sent} delivered, ${result.failed} failed, ` +
        `${result.pruned} pruned, ` +
        `${result.complete ? "complete" : "paused, will resume"}`,
    );

    return {
      session: args.label,
      minutes_before: args.minutesBefore,
      audience: paid ? "registrants" : "everyone",
      sent: result.sent,
      failed: result.failed,
      pruned: result.pruned,
      complete: result.complete,
    };
  } catch (e) {
    // Release the claim so the next run retries from the start, rather
    // than leaving a reminder marked sent that nobody received. Safe to
    // restart only because nothing was delivered: a failure here is the
    // token read or the FCM credentials, both of which fail before the
    // first send rather than partway through.
    if (args.startCursor === null) {
      await supabase
        .from("session_reminders")
        .delete()
        .eq("session_id", args.sessionId)
        .eq("minutes_before", args.minutesBefore);
    }

    const message = e instanceof FcmConfigError
      ? `Push is not configured: ${e.message}`
      : `Send failed: ${e}`;
    console.error(message);
    return {
      session: args.label,
      minutes_before: args.minutesBefore,
      error: message,
    };
  }
}

// deno-lint-ignore no-explicit-any
async function markComplete(supabase: any, sessionId: string, minutes: number) {
  await supabase
    .from("session_reminders")
    .update({ completed_at: new Date().toISOString() })
    .eq("session_id", sessionId)
    .eq("minutes_before", minutes);
}
