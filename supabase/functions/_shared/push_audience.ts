// Who a broadcast goes to, and what to do with the tokens that bounce.
//
// Every push job in this project does the same three things around the
// actual send — read the token list, fan out, delete the tokens FCM says
// are permanently dead. Shared so a second job can't quietly skip the
// pruning and let the list grow forever.

import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { type PushMessage, sendToTokens } from "./fcm.ts";

/** Every registered device. There is no per-user targeting yet: the
 *  things being announced (a new course, the morning meditation, a live
 *  session) are addressed to everybody by nature. When something needs a
 *  narrower audience, that filter belongs here. */
export async function allPushTokens(
  supabase: SupabaseClient,
): Promise<string[]> {
  const { data, error } = await supabase
    .from("push_tokens")
    .select("token")
    .returns<{ token: string }[]>();

  if (error) throw new Error(`Could not read push tokens: ${error.message}`);
  return (data ?? []).map((r) => r.token);
}

export interface BroadcastResult {
  sent: number;
  failed: number;
  pruned: number;
}

/** Fan out, then delete whatever bounced permanently. */
export async function broadcast(
  supabase: SupabaseClient,
  tokens: string[],
  message: PushMessage,
): Promise<BroadcastResult> {
  const result = await sendToTokens(tokens, message);

  if (result.invalidTokens.length > 0) {
    await supabase.from("push_tokens").delete().in(
      "token",
      result.invalidTokens,
    );
  }

  return {
    sent: result.sent,
    failed: result.failed,
    pruned: result.invalidTokens.length,
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
