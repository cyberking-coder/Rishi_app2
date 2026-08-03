// Who a broadcast goes to, how far it got, and what to do with the
// tokens that bounce.
//
// Every push job in this project shares this shape — walk the token list
// in chunks, prune what's dead, remember the position — so a second job
// can't quietly reintroduce the unbounded read this replaced.

import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { type PushMessage, sendToTokens } from "./fcm.ts";

/** Tokens per database read and per FCM batch. Large enough that a small
 *  audience finishes in one round trip, small enough that progress is
 *  recorded often — a chunk is the most work a timeout can cost. */
const CHUNK = 500;

/** How long a single invocation will keep fanning out before saving its
 *  place and returning. Supabase allows appreciably more wall clock than
 *  this; the margin is for the database writes that follow, and for the
 *  chunk already in flight when the budget runs out. */
const DEFAULT_BUDGET_MS = 90_000;

export interface FanOutResult {
  sent: number;
  failed: number;
  pruned: number;
  /** False when the budget ran out with tokens still to go. The caller
   *  must leave the claim open so the next scheduled run finishes it. */
  complete: boolean;
  /** Last token attempted. Persist it; pass it back as `startCursor`. */
  cursor: string | null;
}

/// Sends `message` to every registered device, resuming after
/// `startCursor` if one is given.
///
/// There is no per-user targeting: a new course, the morning meditation
/// and a live session are addressed to everybody by nature. When
/// something needs a narrower audience, the filter belongs in the query
/// below rather than at the call site, so it can't be forgotten by one
/// job and applied by another.
export async function fanOut(
  supabase: SupabaseClient,
  message: PushMessage,
  opts: {
    startCursor?: string | null;
    budgetMs?: number;
    /** Called after each chunk, before the next one starts. This is what
     *  makes the send resumable: if the invocation dies between chunks,
     *  whatever was last persisted here is where the next run begins. */
    onProgress?: (cursor: string, sentSoFar: number) => Promise<void>;
  } = {},
): Promise<FanOutResult> {
  const deadline = Date.now() + (opts.budgetMs ?? DEFAULT_BUDGET_MS);
  let cursor = opts.startCursor ?? null;

  const result: FanOutResult = {
    sent: 0,
    failed: 0,
    pruned: 0,
    complete: false,
    cursor,
  };

  for (;;) {
    // Ordered by token and walked with a strict greater-than, so pruning
    // dead rows mid-walk can't shift anything past the cursor out of
    // reach. Keyset pagination, not offset pagination, for exactly that
    // reason.
    let query = supabase
      .from("push_tokens")
      .select("token")
      .order("token", { ascending: true })
      .limit(CHUNK);

    if (cursor !== null) query = query.gt("token", cursor);

    const { data, error } = await query.returns<{ token: string }[]>();
    if (error) throw new Error(`Could not read push tokens: ${error.message}`);

    const tokens = (data ?? []).map((r) => r.token);
    if (tokens.length === 0) {
      result.complete = true;
      return result;
    }

    const batch = await sendToTokens(tokens, message);
    result.sent += batch.sent;
    result.failed += batch.failed;

    if (batch.invalidTokens.length > 0) {
      await supabase.from("push_tokens").delete().in(
        "token",
        batch.invalidTokens,
      );
      result.pruned += batch.invalidTokens.length;
    }

    // The last token of the chunk as read, not as delivered — a token
    // that failed transiently is still behind us, and retrying it would
    // mean the whole chunk repeats on the next run.
    cursor = tokens[tokens.length - 1];
    result.cursor = cursor;

    await opts.onProgress?.(cursor, result.sent);

    // Deliberately NOT treating a short chunk as the end of the table.
    // PostgREST enforces its own server-side row cap, and if that cap is
    // lower than CHUNK then every page comes back short — which would
    // read as "finished" after the first one and silently reintroduce
    // the truncation this whole mechanism exists to remove. Only an
    // empty page ends the walk, at the cost of one extra round trip.
    if (Date.now() >= deadline) {
      console.log(
        `Fan-out paused after ${result.sent} sends — budget spent, ` +
          `resuming from cursor on the next run.`,
      );
      return result;
    }
  }
}

/// Sends to one person's devices.
///
/// Separate from fanOut rather than a filter on it, because the two have
/// genuinely different shapes: a broadcast is unbounded and has to be
/// resumable, while one user has a handful of devices and always finishes
/// in a single pass. Folding them together would mean carrying cursor
/// machinery through the case that provably never needs it.
export async function sendToUser(
  supabase: SupabaseClient,
  userId: string,
  message: PushMessage,
): Promise<{ sent: number; failed: number; pruned: number }> {
  const { data, error } = await supabase
    .from("push_tokens")
    .select("token")
    .eq("user_id", userId)
    .returns<{ token: string }[]>();

  if (error) {
    throw new Error(`Could not read tokens for ${userId}: ${error.message}`);
  }

  const tokens = (data ?? []).map((r) => r.token);
  if (tokens.length === 0) return { sent: 0, failed: 0, pruned: 0 };

  const batch = await sendToTokens(tokens, message);

  if (batch.invalidTokens.length > 0) {
    await supabase.from("push_tokens").delete().in(
      "token",
      batch.invalidTokens,
    );
  }

  return {
    sent: batch.sent,
    failed: batch.failed,
    pruned: batch.invalidTokens.length,
  };
}

/** Reads the caller's role claim. Signature verification already happened
 *  at the gateway — verify_jwt accepts any valid project JWT, including a
 *  signed-in user's, so this is what actually keeps a fan-out from being
 *  something any account can trigger. */
export function roleFromAuthHeader(header: string | null): string | null {
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
