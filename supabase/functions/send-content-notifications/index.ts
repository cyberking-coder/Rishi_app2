// Edge Function: send-content-notifications
//
// Two jobs, both polled by n8n, both idempotent through notification_log:
//
//   {"job": "new_content"}  — announce courses and audios published since
//                             the last run. Run often (every 15 minutes);
//                             most runs find nothing.
//   {"job": "daily_audio"}  — the "start your day" nudge. Run once a
//                             morning; a second run the same day is a
//                             no-op, which is what makes a retry safe.
//   {"job": "expiry_reminders"} — tells people their access ends in 7, 3
//                             or 1 days, and once more after it has.
//                             There is no auto-renewal in this system, so
//                             this IS the renewal mechanism, not a
//                             courtesy on top of one. Run a few times a
//                             day; the marks are day-grained.
//
// One function rather than two because they share the whole shape —
// claim, fan out, resume, release on failure — and the only thing that
// differs is what gets claimed and what the message says.
//
// Deliveries are resumable: the claim carries how far the send got, so an
// audience too large for one invocation is finished by the next run
// instead of being half-delivered and marked done.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { handlePreflight, jsonResponse } from "../_shared/cors.ts";
import { FcmConfigError, type PushMessage } from "../_shared/fcm.ts";
import {
  fanOut,
  roleFromAuthHeader,
  sendToUser,
} from "../_shared/push_audience.ts";
import { notifyN8nLifecycle } from "../_shared/n8n.ts";

interface DueAnnouncement {
  kind: string;
  target_id: string;
  title: string;
  subtitle: string | null;
  deep_link: string;
}

interface AudioPick {
  id: string;
  title: string;
  description: string | null;
  cover_art_url: string | null;
}

interface DueExpiry {
  user_id: string;
  email: string | null;
  display_name: string | null;
  phone: string | null;
  expires_at: string;
  days_before: number;
  kind: string;
  reminder_key: string;
}

interface OpenClaim {
  kind: string;
  key: string;
  delivery_cursor: string | null;
  recipient_count: number;
  payload: PushMessage | null;
}

/// A description is written to be read on a screen, next to a title, with
/// room to breathe. A notification body has none of that, so it gets one
/// line or nothing — a truncated paragraph reads worse than a plain
/// sentence that was written for the space.
function oneLine(text: string | null, fallback: string): string {
  const trimmed = text?.trim().replace(/\s+/g, " ") ?? "";
  if (trimmed.length === 0) return fallback;
  if (trimmed.length <= 90) return trimmed;
  return `${trimmed.slice(0, 87).trimEnd()}…`;
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

  let body: { job?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const job = body.job ?? "new_content";
  const jobs = ["new_content", "daily_audio", "expiry_reminders"];
  if (!jobs.includes(job)) {
    return jsonResponse(
      { error: `Unknown job "${job}". Use one of ${jobs.join(", ")}.` },
      400,
    );
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Unfinished deliveries first, whichever job asked. They are already
  // claimed, so due_content_announcements() will never surface them again
  // — without this pass, an announcement interrupted by the wall clock
  // would sit half-delivered forever.
  const resumed = await resumeOpenClaims(supabase);

  let result;
  if (job === "daily_audio") result = await runDailyAudio(supabase);
  else if (job === "expiry_reminders") result = await runExpiryReminders(supabase);
  else result = await runNewContent(supabase);

  return jsonResponse({ ...result, resumed });
});

// ---------------------------------------------------------------------------
// Resume
// ---------------------------------------------------------------------------
// deno-lint-ignore no-explicit-any
async function resumeOpenClaims(supabase: any): Promise<unknown[]> {
  const { data: open } = await supabase
    .from("notification_log")
    .select("kind, key, delivery_cursor, recipient_count, payload")
    .is("completed_at", null)
    .order("sent_at", { ascending: true })
    .returns<OpenClaim[]>();

  const outcomes: unknown[] = [];

  for (const claim of (open ?? []) as OpenClaim[]) {
    if (!claim.payload) {
      // Claimed before payloads were stored. Nothing can reconstruct what
      // it was meant to say, and guessing is worse than closing it.
      await supabase
        .from("notification_log")
        .update({ completed_at: new Date().toISOString() })
        .eq("kind", claim.kind)
        .eq("key", claim.key);
      continue;
    }

    outcomes.push(
      await deliver(supabase, claim.payload, {
        kind: claim.kind,
        key: claim.key,
        startCursor: claim.delivery_cursor,
        alreadySent: claim.recipient_count,
        label: `${claim.payload.title} (resumed)`,
      }),
    );
  }

  return outcomes;
}

// ---------------------------------------------------------------------------
// new_content
// ---------------------------------------------------------------------------
// deno-lint-ignore no-explicit-any
async function runNewContent(supabase: any) {
  const { data: due, error } = await supabase
    .rpc("due_content_announcements", { p_lookback_hours: 48 })
    .returns<DueAnnouncement[]>();

  if (error) {
    console.error(`due_content_announcements failed: ${error.message}`);
    return { ok: false, job: "new_content", error: error.message };
  }

  const outcomes: unknown[] = [];

  for (const item of (due ?? []) as DueAnnouncement[]) {
    const isCourse = item.kind === "new_course";
    const payload: PushMessage = {
      title: isCourse ? `New course: ${item.title}` : item.title,
      body: oneLine(
        item.subtitle,
        isCourse
          ? "Just added. Tap to take a look."
          : "A new meditation is waiting for you.",
      ),
      data: {
        type: item.kind,
        target_id: item.target_id,
        deep_link: item.deep_link,
      },
      channelId: "content_updates",
    };

    const claimed = await claim(supabase, item.kind, item.target_id, payload);
    if (claimed !== "claimed") {
      outcomes.push({ title: item.title, skipped: claimed });
      continue;
    }

    outcomes.push(
      await deliver(supabase, payload, {
        kind: item.kind,
        key: item.target_id,
        startCursor: null,
        alreadySent: 0,
        label: item.title,
      }),
    );
  }

  return { ok: true, job: "new_content", due: (due ?? []).length, outcomes };
}

// ---------------------------------------------------------------------------
// daily_audio
// ---------------------------------------------------------------------------
// deno-lint-ignore no-explicit-any
async function runDailyAudio(supabase: any) {
  // The key is a date, so "once a day" holds however often the cron
  // fires. UTC deliberately: the job runs at one moment for everybody,
  // and a per-viewer local date would make "today" ambiguous at exactly
  // the moment the guard needs to be unambiguous.
  const today = new Date().toISOString().slice(0, 10);

  const { data: picks, error } = await supabase
    .rpc("daily_audio_pick")
    .returns<AudioPick[]>();

  if (error) {
    console.error(`daily_audio_pick failed: ${error.message}`);
    return { ok: false, job: "daily_audio", error: error.message };
  }

  const pick = (picks ?? [])[0] as AudioPick | undefined;
  if (!pick) {
    // An empty library is not a failure — it is a morning with nothing to
    // recommend. Claiming the day anyway would waste it, so it isn't
    // claimed: if audio is published later today, tonight's run sends.
    console.log("No published audio to feature today.");
    return { ok: true, job: "daily_audio", sent: 0 };
  }

  const payload: PushMessage = {
    title: "Start your day",
    body: `${pick.title} — tap to listen.`,
    data: {
      type: "daily_audio",
      target_id: pick.id,
      deep_link: `/audio/${pick.id}`,
    },
    channelId: "content_updates",
  };

  const claimed = await claim(
    supabase,
    "daily_audio",
    today,
    payload,
    pick.id,
  );
  if (claimed !== "claimed") {
    return { ok: true, job: "daily_audio", skipped: claimed };
  }

  const outcome = await deliver(supabase, payload, {
    kind: "daily_audio",
    key: today,
    startCursor: null,
    alreadySent: 0,
    label: pick.title,
  });

  return { ok: true, job: "daily_audio", featured: pick.title, ...outcome };
}

// ---------------------------------------------------------------------------
// expiry_reminders
// ---------------------------------------------------------------------------
/// Addressed to one person at a time, unlike everything else here.
///
/// Push and WhatsApp are sent independently and neither can block the
/// other: somebody who never installed the app still has a phone number,
/// and somebody who never bought through checkout has devices but no
/// number. Requiring both would silently drop whichever group was
/// missing its channel.
// deno-lint-ignore no-explicit-any
async function runExpiryReminders(supabase: any) {
  const { data: due, error } = await supabase
    .rpc("due_expiry_reminders", { p_window_hours: 26 })
    .returns<DueExpiry[]>();

  if (error) {
    console.error(`due_expiry_reminders failed: ${error.message}`);
    return { ok: false, job: "expiry_reminders", error: error.message };
  }

  const outcomes: unknown[] = [];

  for (const item of (due ?? []) as DueExpiry[]) {
    const lapsed = item.kind === "access_lapsed";
    const payload: PushMessage = {
      title: lapsed ? "Your access has ended" : "Your access is ending soon",
      body: lapsed
        ? "Renew to pick up where you left off."
        : `${daysPhrase(item.days_before)} left. Renew to keep your ` +
          `meditations and courses.`,
      data: {
        type: item.kind,
        deep_link: "/profile",
      },
      channelId: "content_updates",
    };

    const claimed = await claim(
      supabase,
      item.kind,
      item.reminder_key,
      payload,
      item.user_id,
    );
    if (claimed !== "claimed") {
      outcomes.push({ user: item.user_id, skipped: claimed });
      continue;
    }

    let push = { sent: 0, failed: 0, pruned: 0 };
    let pushError: string | null = null;
    try {
      push = await sendToUser(supabase, item.user_id, payload);
    } catch (e) {
      pushError = describe(e);
      console.error(`Expiry push to ${item.user_id} failed: ${pushError}`);
    }

    let whatsapp: string = "sent";
    try {
      await notifyN8nLifecycle({
        event: lapsed ? "access_lapsed" : "access_expiring",
        user_id: item.user_id,
        email: item.email,
        name: item.display_name,
        phone: item.phone,
        days_before: item.days_before,
        expires_at: item.expires_at,
      });
    } catch (e) {
      whatsapp = describe(e);
      console.error(`Expiry n8n notify for ${item.user_id} failed: ${whatsapp}`);
    }

    // Marked complete either way. A reminder that reached one channel and
    // not the other should not be re-sent in full an hour later — the
    // people it did reach would get it twice, which reads worse than the
    // people it missed getting it once.
    await supabase
      .from("notification_log")
      .update({
        recipient_count: push.sent,
        completed_at: new Date().toISOString(),
      })
      .eq("kind", item.kind)
      .eq("key", item.reminder_key);

    outcomes.push({
      user: item.user_id,
      kind: item.kind,
      days_before: item.days_before,
      push: pushError ?? `${push.sent} delivered`,
      whatsapp,
    });
  }

  return { ok: true, job: "expiry_reminders", due: (due ?? []).length, outcomes };
}

/// "7 days" / "3 days" / "1 day" — the singular matters because the
/// one-day notice is the one people actually act on.
function daysPhrase(days: number): string {
  return days === 1 ? "1 day" : `${days} days`;
}

// ---------------------------------------------------------------------------
// Shared claim / deliver
// ---------------------------------------------------------------------------
/// Claims BEFORE sending, so two overlapping runs produce one
/// notification rather than two. The unique constraint on (kind, key) is
/// what actually enforces it; this just reports which side of the race we
/// were on.
async function claim(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  kind: string,
  key: string,
  payload: PushMessage,
  targetId?: string,
): Promise<"claimed" | string> {
  const { error } = await supabase.from("notification_log").insert({
    kind,
    key,
    target_id: targetId ?? key,
    recipient_count: 0,
    payload,
  });

  if (!error) return "claimed";
  if (error.code === "23505") return "already sent";

  console.error(`Could not claim ${kind}/${key}: ${error.message}`);
  return error.message;
}

async function deliver(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  payload: PushMessage,
  args: {
    kind: string;
    key: string;
    startCursor: string | null;
    alreadySent: number;
    label: string;
  },
): Promise<Record<string, unknown>> {
  try {
    const result = await fanOut(supabase, payload, {
      startCursor: args.startCursor,
      onProgress: async (cursor, sentSoFar) => {
        await supabase
          .from("notification_log")
          .update({
            delivery_cursor: cursor,
            recipient_count: args.alreadySent + sentSoFar,
          })
          .eq("kind", args.kind)
          .eq("key", args.key);
      },
    });

    await supabase
      .from("notification_log")
      .update({
        delivery_cursor: result.cursor,
        recipient_count: args.alreadySent + result.sent,
        completed_at: result.complete ? new Date().toISOString() : null,
      })
      .eq("kind", args.kind)
      .eq("key", args.key);

    console.log(
      `Announced ${args.kind} "${args.label}" — ${result.sent} delivered, ` +
        `${result.failed} failed, ${result.pruned} pruned, ` +
        `${result.complete ? "complete" : "paused, will resume"}`,
    );

    return {
      title: args.label,
      sent: result.sent,
      failed: result.failed,
      pruned: result.pruned,
      complete: result.complete,
    };
  } catch (e) {
    // Release the claim so the next run retries from the start, rather
    // than leaving something marked announced that nobody was told about.
    // Only safe when nothing was delivered — a failure here is the token
    // read or the FCM credentials, both of which fail before the first
    // send rather than partway through. A claim that already has a cursor
    // keeps it and resumes instead.
    if (args.startCursor === null) {
      await supabase
        .from("notification_log")
        .delete()
        .eq("kind", args.kind)
        .eq("key", args.key);
    }

    const message = describe(e);
    console.error(`Announcing "${args.label}" failed: ${message}`);
    return { title: args.label, error: message };
  }
}

/// A missing FCM service account is a configuration problem with a fix,
/// and says so; anything else is reported as it arrived.
function describe(e: unknown): string {
  return e instanceof FcmConfigError
    ? `Push is not configured: ${e.message}`
    : String(e);
}
