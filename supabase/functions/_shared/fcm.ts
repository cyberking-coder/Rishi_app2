// Firebase Cloud Messaging, HTTP v1.
//
// v1 is per-token: there is no multicast send in the REST API (the
// legacy batch endpoint is retired), so a fan-out is N requests. That is
// fine at this size and is why send() takes a token list and paces
// itself rather than pretending one call covers everyone.

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

/** Result of one fan-out. `invalidTokens` are the ones FCM says are dead
 *  — deleting them is the only thing that stops the list growing without
 *  limit as people reinstall. */
export interface SendResult {
  sent: number;
  failed: number;
  invalidTokens: string[];
}

export class FcmConfigError extends Error {}

function serviceAccount(): ServiceAccount {
  const raw = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!raw) {
    throw new FcmConfigError(
      "FCM_SERVICE_ACCOUNT is not set. Paste the whole service-account " +
        "JSON from Firebase console → Project settings → Service accounts.",
    );
  }

  let parsed: ServiceAccount;
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new FcmConfigError(
      "FCM_SERVICE_ACCOUNT is not valid JSON. It must be the file's full " +
        "contents, not a path or a key id.",
    );
  }

  if (!parsed.project_id || !parsed.client_email || !parsed.private_key) {
    throw new FcmConfigError(
      "FCM_SERVICE_ACCOUNT is missing project_id, client_email or private_key.",
    );
  }
  return parsed;
}

function base64Url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function base64UrlJson(value: unknown): string {
  return base64Url(new TextEncoder().encode(JSON.stringify(value)));
}

/// The PEM arrives with literal "\n" sequences when it has been through
/// an environment variable, and with real newlines when it hasn't. Both
/// happen in practice, so normalise rather than assume.
function pemToPkcs8(pem: string): Uint8Array {
  const body = pem
    .replace(/\\n/g, "\n")
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const binary = atob(body);
  return Uint8Array.from(binary, (c) => c.charCodeAt(0));
}

/// Access tokens last an hour; a single function invocation is far
/// shorter than that, so one mint per invocation and no caching layer.
async function accessToken(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const claim = {
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const unsigned = `${base64UrlJson({ alg: "RS256", typ: "JWT" })}.` +
    base64UrlJson(claim);

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToPkcs8(account.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      key,
      new TextEncoder().encode(unsigned),
    ),
  );

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${unsigned}.${base64Url(signature)}`,
    }),
  });

  if (!res.ok) {
    const detail = await res.text().catch(() => "");
    throw new Error(
      `Google refused the service-account assertion (${res.status}). ` +
        `Usually a clock skew or a revoked key. ${detail.slice(0, 300)}`,
    );
  }

  const body = await res.json() as { access_token?: string };
  if (!body.access_token) {
    throw new Error("Google returned no access_token.");
  }
  return body.access_token;
}

export interface PushMessage {
  title: string;
  body: string;
  /** Delivered to the app as message.data — strings only, FCM rejects
   *  anything else. */
  data?: Record<string, string>;
  /** Android channel. Must match a channel PushService creates in the
   *  app, or Android files the notification under a default one and the
   *  importance settings are silently lost. Reminders about something
   *  starting and announcements about something new are separate
   *  channels so a user can mute one without losing the other. */
  channelId?: "session_reminders" | "content_updates";
}

/// Sends one message to many tokens.
///
/// Every token is attempted even when earlier ones fail: one dead
/// handset must not stop the reminder reaching everybody else. Failures
/// are counted and the dead ones named, so the caller can prune.
export async function sendToTokens(
  tokens: string[],
  message: PushMessage,
): Promise<SendResult> {
  if (tokens.length === 0) return { sent: 0, failed: 0, invalidTokens: [] };

  const account = serviceAccount();
  const token = await accessToken(account);
  const endpoint =
    `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`;

  const result: SendResult = { sent: 0, failed: 0, invalidTokens: [] };

  // Bounded concurrency. Unbounded would open a socket per device and
  // trip Deno's limits on a large list; serial would time the function
  // out.
  //
  // 100, not 20: these all go to one host over HTTP/2, so they share
  // connections rather than opening a socket each, and the round trip
  // dominates. At 20 a hundred thousand devices took long enough that
  // the invocation's wall clock became the real limit rather than a
  // theoretical one.
  const CONCURRENCY = 100;
  let cursor = 0;

  async function worker() {
    while (cursor < tokens.length) {
      const deviceToken = tokens[cursor++];
      try {
        const res = await fetch(endpoint, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token: deviceToken,
              notification: { title: message.title, body: message.body },
              data: message.data ?? {},
              android: {
                priority: "high",
                notification: {
                  channel_id: message.channelId ?? "session_reminders",
                  // Tapping opens the launcher activity; the app then
                  // routes on the data payload.
                  click_action: "FLUTTER_NOTIFICATION_CLICK",
                },
              },
            },
          }),
        });

        if (res.ok) {
          result.sent++;
          continue;
        }

        result.failed++;
        const detail = await res.text().catch(() => "");
        // Permanent failures, all of which mean the row is dead:
        //   404 UNREGISTERED     — app uninstalled, or the token reissued
        //   400 INVALID_ARGUMENT — the token was never valid
        //   403 SENDER_ID_MISMATCH — the token belongs to a different
        //     Firebase project. Happens whenever the app is repointed at
        //     a new project, and the old rows would otherwise fail on
        //     every send forever, because nothing else ever removes them.
        // Anything else (429, 503) is transient and the token must be
        // kept — pruning on a momentary outage would delete live devices.
        if (
          res.status === 404 ||
          (res.status === 400 && detail.includes("INVALID_ARGUMENT")) ||
          (res.status === 403 && detail.includes("SENDER_ID_MISMATCH"))
        ) {
          result.invalidTokens.push(deviceToken);
        } else {
          console.warn(`FCM ${res.status} for a token: ${detail.slice(0, 200)}`);
        }
      } catch (e) {
        result.failed++;
        console.warn(`FCM request threw: ${e}`);
      }
    }
  }

  await Promise.all(
    Array.from({ length: Math.min(CONCURRENCY, tokens.length) }, worker),
  );

  return result;
}
