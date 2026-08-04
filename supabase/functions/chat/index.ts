// Edge Function: chat
//
// The in-app assistant. Answers practice questions ("how long should I
// sit for?"), navigation questions ("which of these should I start
// with?") and account questions, grounded in the actual library rather
// than in whatever the model remembers about meditation apps.
//
// The API key lives here and only here. A key shipped inside the Flutter
// binary is a key in the hands of anyone who unzips the APK, and it
// cannot be rotated without a store release — so the app never sees one,
// and every request is attributable to a signed-in user.
//
// Three things this function is responsible for that the model is not:
//
//   1. The daily allowance. Enforced before the upstream call, because a
//      cap checked after the expensive part has already happened is not
//      a cap.
//   2. Grounding. The catalogue and the caller's own history go in as
//      system context, so recommendations name tracks that exist.
//   3. The safety boundary. A meditation app gets asked about panic
//      attacks, grief and worse. The instructions below are what decide
//      whether that gets a warm hand-off or an improvised therapist.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { handlePreflight, jsonResponse } from "../_shared/cors.ts";

/// Messages per person per day. Generous for someone using this as
/// intended; a wall for a script. Overridable without a redeploy.
const DAILY_LIMIT = Number(Deno.env.get("CHAT_DAILY_LIMIT") ?? "20");

/// How much of the conversation goes back up with each turn. Enough for
/// "and what about the second one?" to make sense, short enough that a
/// long session doesn't grow without bound.
const HISTORY_TURNS = 12;

/// Haiku rather than Sonnet, deliberately. The work here is short,
/// grounded answers over a catalogue that is handed to it — the ceiling
/// on quality is the context, not the model — and at a 20-a-day
/// allowance across a free user base the difference between the two is
/// the difference between a bill worth paying and one worth cancelling.
/// Set CHAT_MODEL to a Sonnet id if the answers ever feel thin.
const MODEL = Deno.env.get("CHAT_MODEL") ?? "claude-haiku-4-5-20251001";

const MAX_INPUT_CHARS = 1500;
const MAX_OUTPUT_TOKENS = 700;

interface Catalogue {
  audios: unknown[];
  courses: unknown[];
}

/// The assistant's brief.
///
/// Written as one static block on purpose: it is the same bytes for
/// every caller, so it sits at the front of the prompt where it can be
/// cached alongside the catalogue.
const INSTRUCTIONS = `
You are the in-app guide for "Know Thyself", the meditation app of
Anurag Rishi. You help people who are already inside the app: they have
opened it, they want to practise, and they are asking you what to do
next.

VOICE
- Warm, plain and unhurried. Short paragraphs. No exclamation marks, no
  emoji, no "Namaste" unless the user opens that way.
- Speak to one person. "Try sitting for ten minutes" — not "users can".
- Two to five sentences is the normal length of a good answer here.
  Expand only when the question genuinely needs steps.

LANGUAGE
Answer in the language the person wrote or spoke in. This app is used
across India and the three that matter here are English, Hindi and
Marathi.

- Devanagari in, Devanagari out. If they write हिंदी, answer in हिंदी;
  if they write मराठी, answer in मराठी. Do not answer a Devanagari
  question in English, and do not transliterate your answer into Roman
  script unless they wrote to you that way.
- Roman-script Hindi or Marathi — "mujhe neend nahi aati", "mala shant
  vatat nahi" — is answered in the same Roman script, not in
  Devanagari. Someone typing on an English keyboard usually wants to
  read the reply the same way.
- Hinglish is its own register. Match it rather than correcting it into
  formal Hindi.
- Hold the language across the conversation. Switch only when they do.
- Marathi is not a dialect of Hindi. If someone writes Marathi, do not
  reply in Hindi and assume it is close enough.

Two things stay in their original form whatever the language:

- Track and course titles, quoted exactly as they appear in the
  catalogue. A translated title cannot be found by anybody searching
  for it, and the link label should match the screen it opens.
- The helpline numbers below. Introduce them in the person's language,
  but never alter a digit.

WHAT YOU KNOW
- The catalogue below is the entire library. It is the only source of
  track and course names you may use. Never invent a title, never
  recommend "a body scan meditation" as though one exists unless you can
  see it in the list, and never promise content that is coming soon.
- If nothing in the library fits what they are asking for, say so
  plainly and offer the closest thing that does.
- You can see what this person has listened to. Use it: acknowledge
  where they left off, don't recommend the thing they finished
  yesterday, and don't assume a beginner if they have thirty sittings
  behind them.
- Some content is marked premium. If they don't have access and the best
  answer is a premium track, say it's part of the membership rather than
  pretending it's free — but always name a free option too if one
  exists.

LINKING
When you name something in the library, make it tappable by writing it
as a markdown link with the id from the catalogue:
  [Morning Stillness](app://audio/<id>)
  [The Inner Path](app://course/<id>)
Use the exact id. One or two links in an answer, not a list of eight. If
you are not naming a specific piece of content, don't link anything.

WHAT YOU ARE NOT
- Not a doctor, a therapist or a diagnosis. You do not interpret
  symptoms, comment on medication, or tell anyone whether to keep taking
  something.
- Not the support desk for payments. Refunds, failed payments, billing
  and access problems go to the team — say so and stop, rather than
  guessing at what the app will do.

WHEN SOMEONE IS STRUGGLING
People bring panic, grief, insomnia and worse to an app like this. Meet
it, don't deflect it: acknowledge what they said in your own words, and
offer one small thing that might genuinely help right now — a breath
practice, a short track, permission to stop trying to meditate today.

If someone mentions suicide, self-harm, or being unable to keep
themselves safe, drop everything else. Do not recommend a meditation. Do
not ask them to breathe. Tell them plainly that this is bigger than an
app, that help exists and is free, and give these numbers:

  Tele-MANAS (Government of India, 24x7): 14416
  AASRA: 9820466726
  Vandrevala Foundation: 9999 666 555
  iCall: 9152987821

Say that if they are in immediate danger they should call 112 or get to
the nearest hospital. Stay warm and stay with them; do not end the
conversation, and do not lecture.

Tele-MANAS answers in Hindi, Marathi and English, and iCall in Marathi —
worth saying to someone who wrote to you in one of those, because "will
they even understand me" is a real reason people don't ring.

WHEN YOU DON'T KNOW
Say you don't know, and say who does. A confident wrong answer about
someone's practice or their money costs more than an honest blank.
`.trim();

Deno.serve(async (req) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) {
    // A configuration failure, not the user's. Logged loudly, reported
    // gently — nobody typing a question needs to hear about secrets.
    console.error("ANTHROPIC_API_KEY is not set — chat is disabled.");
    return jsonResponse({ error: "The guide is unavailable right now." }, 503);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: "Missing Authorization header" }, 401);
  }

  let body: { message?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const message = (body.message ?? "").trim();
  if (message.length === 0) {
    return jsonResponse({ error: "message is required" }, 400);
  }
  if (message.length > MAX_INPUT_CHARS) {
    return jsonResponse(
      { error: `Please keep it under ${MAX_INPUT_CHARS} characters.` },
      400,
    );
  }

  // The caller's own JWT, so every read below is the caller's read: RLS
  // decides what they can see, and this function never holds a key that
  // could reach another person's conversation.
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData.user) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }
  const userId = userData.user.id;

  // ── Allowance ─────────────────────────────────────────────────────
  const { data: quotaRows, error: quotaError } = await supabase
    .rpc("chat_quota", { p_limit: DAILY_LIMIT })
    .returns<{ used: number; allowance: number; resets_at: string }[]>();

  if (quotaError) {
    console.error("chat_quota failed:", quotaError.message);
    return jsonResponse({ error: "The guide is unavailable right now." }, 503);
  }

  const quota = quotaRows?.[0] ?? {
    used: 0,
    allowance: DAILY_LIMIT,
    resets_at: new Date().toISOString(),
  };

  if (quota.used >= quota.allowance) {
    return jsonResponse({
      error:
        `You've reached today's ${quota.allowance} questions. The guide ` +
        `is back tomorrow — the meditations aren't going anywhere in the ` +
        `meantime.`,
      remaining: 0,
      resets_at: quota.resets_at,
    }, 429);
  }

  // ── Context ───────────────────────────────────────────────────────
  const [catalogueRes, contextRes, historyRes] = await Promise.all([
    supabase.rpc("chat_catalogue"),
    supabase.rpc("chat_user_context"),
    supabase
      .from("chat_messages")
      .select("role, content")
      .order("created_at", { ascending: false })
      .limit(HISTORY_TURNS)
      .returns<{ role: string; content: string }[]>(),
  ]);

  if (catalogueRes.error || contextRes.error || historyRes.error) {
    const detail = catalogueRes.error?.message ?? contextRes.error?.message ??
      historyRes.error?.message;
    console.error("Could not assemble chat context:", detail);
    return jsonResponse({ error: "The guide is unavailable right now." }, 503);
  }

  const catalogue = catalogueRes.data as Catalogue;
  const userContext = contextRes.data as Record<string, unknown>;

  // Read newest-first (the index runs that way), used oldest-first.
  const history = [...(historyRes.data ?? [])].reverse();

  // The window can open on an assistant reply — the user's question that
  // prompted it fell off the front. The API rejects a conversation that
  // starts with the assistant, so those orphans are dropped rather than
  // sent: a reply with nothing before it adds no context anyway.
  while (history.length > 0 && history[0].role !== "user") history.shift();

  const messages = [
    ...history.map((m) => ({ role: m.role, content: m.content })),
    { role: "user", content: message },
  ];

  // Three system blocks, in this order, and the order is the whole point.
  // Blocks one and two are byte-identical for every user, so the cache
  // breakpoint after the catalogue is a prefix that every request in the
  // app shares. Block three is this person's history, which changes
  // constantly — putting it before the catalogue would invalidate the
  // cache on every single call and make the catalogue cost full price
  // forever.
  const system = [
    { type: "text", text: INSTRUCTIONS },
    {
      type: "text",
      text: `THE LIBRARY (the only content that exists):\n${
        JSON.stringify(catalogue)
      }`,
      cache_control: { type: "ephemeral" },
    },
    {
      type: "text",
      text: `ABOUT THE PERSON YOU ARE TALKING TO:\n${
        JSON.stringify(userContext)
      }`,
    },
  ];

  let reply: string;
  try {
    const res = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: MAX_OUTPUT_TOKENS,
        system,
        messages,
      }),
    });

    if (!res.ok) {
      const detail = await res.text();
      console.error(`Anthropic API ${res.status}: ${detail}`);
      // 429 upstream is a rate limit on the whole app, not on this
      // person, so it must not read as "you asked too much".
      return jsonResponse({
        error: res.status === 429
          ? "The guide is busy. Try again in a moment."
          : "The guide is unavailable right now.",
      }, 503);
    }

    const payload = await res.json() as {
      content?: { type: string; text?: string }[];
    };

    reply = (payload.content ?? [])
      .filter((b) => b.type === "text")
      .map((b) => b.text ?? "")
      .join("")
      .trim();

    if (reply.length === 0) {
      // An empty completion is rare but not impossible (a refusal or a
      // stop at zero tokens). Persisting nothing and saying nothing
      // would leave the user's own message stored with no answer beside
      // it, which reads as a bug on every future load.
      throw new Error("Empty completion");
    }
  } catch (e) {
    console.error("Chat completion failed:", e);
    return jsonResponse({ error: "The guide is unavailable right now." }, 503);
  }

  // Stored only after a reply exists, both rows together. A failed turn
  // therefore leaves no trace — it costs the user nothing from their
  // allowance and leaves no half-conversation to reload.
  const { error: insertError } = await supabase.from("chat_messages").insert([
    { user_id: userId, role: "user", content: message },
    { user_id: userId, role: "assistant", content: reply },
  ]);

  if (insertError) {
    // The answer is already paid for and is worth more than the record
    // of it. Return it, log the failure, move on.
    console.error("Could not persist chat turn:", insertError.message);
  }

  return jsonResponse({
    reply,
    remaining: Math.max(0, quota.allowance - quota.used - 1),
    resets_at: quota.resets_at,
  });
});
