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
//
// One function rather than two because they share the whole shape —
// claim, fan out, release on failure — and the only thing that differs is
// what gets claimed and what the message says.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { handlePreflight, jsonResponse } from "../_shared/cors.ts";
import { FcmConfigError } from "../_shared/fcm.ts";
import {
  allPushTokens,
  broadcast,
  roleFromAuthHeader,
} from "../_shared/push_audience.ts";

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
  if (job !== "new_content" && job !== "daily_audio") {
    return jsonResponse(
      { error: `Unknown job "${job}". Use "new_content" or "daily_audio".` },
      400,
    );
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  let tokens: string[];
  try {
    tokens = await allPushTokens(supabase);
  } catch (e) {
    console.error(String(e));
    return jsonResponse({ error: String(e) }, 500);
  }

  return job === "daily_audio"
    ? await runDailyAudio(supabase, tokens)
    : await runNewContent(supabase, tokens);
});

// ---------------------------------------------------------------------------
// new_content
// ---------------------------------------------------------------------------
async function runNewContent(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  tokens: string[],
): Promise<Response> {
  const { data: due, error } = await supabase
    .rpc("due_content_announcements", { p_lookback_hours: 48 })
    .returns<DueAnnouncement[]>();

  if (error) {
    console.error(`due_content_announcements failed: ${error.message}`);
    return jsonResponse({ error: error.message }, 500);
  }

  if (!due || due.length === 0) {
    return jsonResponse({ ok: true, job: "new_content", due: 0 });
  }

  const outcomes: Record<string, unknown>[] = [];

  for (const item of due) {
    const isCourse = item.kind === "new_course";

    const claimed = await claim(supabase, {
      kind: item.kind,
      key: item.target_id,
      targetId: item.target_id,
      recipientCount: tokens.length,
    });
    if (claimed !== "claimed") {
      outcomes.push({ title: item.title, skipped: claimed });
      continue;
    }

    try {
      const result = await broadcast(supabase, tokens, {
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
      });

      await supabase
        .from("notification_log")
        .update({ recipient_count: result.sent })
        .eq("kind", item.kind)
        .eq("key", item.target_id);

      console.log(
        `Announced ${item.kind} "${item.title}" — ${result.sent} delivered, ` +
          `${result.failed} failed, ${result.pruned} pruned`,
      );
      outcomes.push({ title: item.title, ...result });
    } catch (e) {
      await release(supabase, item.kind, item.target_id);
      const message = describe(e);
      console.error(`Announcing "${item.title}" failed: ${message}`);
      outcomes.push({ title: item.title, error: message });
    }
  }

  return jsonResponse({
    ok: true,
    job: "new_content",
    due: due.length,
    outcomes,
  });
}

// ---------------------------------------------------------------------------
// daily_audio
// ---------------------------------------------------------------------------
async function runDailyAudio(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  tokens: string[],
): Promise<Response> {
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
    return jsonResponse({ error: error.message }, 500);
  }

  const pick = picks?.[0];
  if (!pick) {
    // An empty library is not a failure — it is a morning with nothing to
    // recommend. Claiming the day anyway would waste it, so it isn't
    // claimed: if audio is published later today, tonight's run sends.
    console.log("No published audio to feature today.");
    return jsonResponse({ ok: true, job: "daily_audio", sent: 0 });
  }

  const claimed = await claim(supabase, {
    kind: "daily_audio",
    key: today,
    targetId: pick.id,
    recipientCount: tokens.length,
  });
  if (claimed !== "claimed") {
    return jsonResponse({ ok: true, job: "daily_audio", skipped: claimed });
  }

  try {
    const result = await broadcast(supabase, tokens, {
      title: "Start your day",
      body: `${pick.title} — tap to listen.`,
      data: {
        type: "daily_audio",
        target_id: pick.id,
        deep_link: `/audio/${pick.id}`,
      },
      channelId: "content_updates",
    });

    await supabase
      .from("notification_log")
      .update({ recipient_count: result.sent })
      .eq("kind", "daily_audio")
      .eq("key", today);

    console.log(
      `Daily audio "${pick.title}" — ${result.sent} delivered, ` +
        `${result.failed} failed, ${result.pruned} pruned`,
    );
    return jsonResponse({
      ok: true,
      job: "daily_audio",
      featured: pick.title,
      ...result,
    });
  } catch (e) {
    await release(supabase, "daily_audio", today);
    const message = describe(e);
    console.error(`Daily audio send failed: ${message}`);
    return jsonResponse({ error: message }, 500);
  }
}

// ---------------------------------------------------------------------------
// Shared claim / release
// ---------------------------------------------------------------------------
/// Claims BEFORE sending, so two overlapping runs produce one
/// notification rather than two. The unique constraint on
/// (kind, key) is what actually enforces it; this just reports which side
/// of the race we were on.
async function claim(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  args: {
    kind: string;
    key: string;
    targetId: string | null;
    recipientCount: number;
  },
): Promise<"claimed" | string> {
  const { error } = await supabase.from("notification_log").insert({
    kind: args.kind,
    key: args.key,
    target_id: args.targetId,
    recipient_count: args.recipientCount,
  });

  if (!error) return "claimed";
  if (error.code === "23505") return "already sent";

  console.error(`Could not claim ${args.kind}/${args.key}: ${error.message}`);
  return error.message;
}

/// Releases a claim whose send failed, so the next run retries rather
/// than leaving something marked announced that nobody was told about.
// deno-lint-ignore no-explicit-any
async function release(supabase: any, kind: string, key: string) {
  await supabase
    .from("notification_log")
    .delete()
    .eq("kind", kind)
    .eq("key", key);
}

function describe(e: unknown): string {
  return e instanceof FcmConfigError
    ? `Push is not configured: ${e.message}`
    : String(e);
}
