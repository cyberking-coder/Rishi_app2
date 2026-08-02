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
// Caller must present the service-role key. verify_jwt is left ON for
// this function (it accepts any valid project JWT), so the role check
// below is what actually restricts it — without it, any signed-in user
// could trigger a fan-out.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { handlePreflight, jsonResponse } from "../_shared/cors.ts";
import { FcmConfigError, sendToTokens } from "../_shared/fcm.ts";

interface DueReminder {
  session_id: string;
  title: string;
  starts_at: string;
  join_url: string;
  minutes_before: number;
}

/// "in an hour" / "in 30 minutes" / "in 5 minutes". Written out rather
/// than templated from the number so the 60 case doesn't read as "in 60
/// minutes", which nobody says.
function whenPhrase(minutes: number): string {
  if (minutes >= 60) return "in an hour";
  return `in ${minutes} minutes`;
}

/// Returns the caller's role claim, or null if the token is unreadable.
/// Signature verification has already happened at the gateway; this only
/// needs to read what was verified.
function roleFromAuthHeader(header: string | null): string | null {
  if (!header?.startsWith("Bearer ")) return null;
  const parts = header.slice(7).split(".");
  if (parts.length !== 3) return null;
  try {
    const payload = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const padded = payload.padEnd(
      payload.length + ((4 - (payload.length % 4)) % 4),
      "=",
    );
    return (JSON.parse(atob(padded)) as { role?: string }).role ?? null;
  } catch {
    return null;
  }
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

  const { data: due, error: dueError } = await supabase
    .rpc("due_session_reminders", { p_window_minutes: 10 })
    .returns<DueReminder[]>();

  if (dueError) {
    console.error(`due_session_reminders failed: ${dueError.message}`);
    return jsonResponse({ error: dueError.message }, 500);
  }

  if (!due || due.length === 0) {
    return jsonResponse({ ok: true, due: 0, sent: 0 });
  }

  const { data: tokenRows, error: tokenError } = await supabase
    .from("push_tokens")
    .select("token")
    .returns<{ token: string }[]>();

  if (tokenError) {
    console.error(`Could not read push tokens: ${tokenError.message}`);
    return jsonResponse({ error: tokenError.message }, 500);
  }

  const tokens = (tokenRows ?? []).map((r) => r.token);
  const outcomes: Record<string, unknown>[] = [];

  for (const reminder of due) {
    // Claim BEFORE sending. Two overlapping cron runs both see the same
    // due row, and the unique constraint is what makes only one of them
    // send. Claiming afterwards would let both through and double-notify
    // everyone — the same mistake the payment webhook made, in reverse.
    const { error: claimError } = await supabase
      .from("session_reminders")
      .insert({
        session_id: reminder.session_id,
        minutes_before: reminder.minutes_before,
        recipient_count: tokens.length,
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

    let result;
    try {
      result = await sendToTokens(tokens, {
        title: reminder.title,
        body: `Starts ${whenPhrase(reminder.minutes_before)}. ` +
          `Open the app and tap to join.`,
        data: {
          type: "live_session",
          session_id: reminder.session_id,
          join_url: reminder.join_url,
        },
      });
    } catch (e) {
      // Release the claim so the next run retries, rather than leaving a
      // reminder permanently marked sent when nothing was sent. A config
      // error is the one exception: retrying it just burns runs, so it
      // stays claimed only if it isn't a config problem.
      await supabase
        .from("session_reminders")
        .delete()
        .eq("session_id", reminder.session_id)
        .eq("minutes_before", reminder.minutes_before);

      const message = e instanceof FcmConfigError
        ? `Push is not configured: ${e.message}`
        : `Send failed: ${e}`;
      console.error(message);
      outcomes.push({
        session: reminder.title,
        minutes_before: reminder.minutes_before,
        error: message,
      });
      continue;
    }

    if (result.invalidTokens.length > 0) {
      await supabase
        .from("push_tokens")
        .delete()
        .in("token", result.invalidTokens);
    }

    // The claim was written before the recipient count was known; correct
    // it now that it is, so the dashboard shows what actually landed.
    await supabase
      .from("session_reminders")
      .update({ recipient_count: result.sent })
      .eq("session_id", reminder.session_id)
      .eq("minutes_before", reminder.minutes_before);

    console.log(
      `Reminder sent: "${reminder.title}" ${reminder.minutes_before}m — ` +
        `${result.sent} delivered, ${result.failed} failed, ` +
        `${result.invalidTokens.length} tokens pruned`,
    );

    outcomes.push({
      session: reminder.title,
      minutes_before: reminder.minutes_before,
      sent: result.sent,
      failed: result.failed,
      pruned: result.invalidTokens.length,
    });
  }

  return jsonResponse({ ok: true, due: due.length, outcomes });
});
