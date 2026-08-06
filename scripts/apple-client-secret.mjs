#!/usr/bin/env node
/**
 * Mints the "Secret Key (for OAuth)" that Supabase's Apple provider asks
 * for — a JWT signed with your Apple .p8 private key.
 *
 * ONLY needed for the WEB OAuth flow. Native Sign in with Apple (which
 * is what this app does) validates the token against the Client IDs list
 * instead, and needs none of this.
 *
 * No dependencies: Node's own crypto signs ES256 with a PKCS#8 EC key,
 * so there is nothing to npm install and nothing to trust.
 *
 * Run it where the .p8 is. The key never leaves your machine.
 *
 *   node scripts/apple-client-secret.mjs \
 *     --key ./AuthKey_ABC123XYZ.p8 \
 *     --key-id ABC123XYZ \
 *     --team-id AGP29KH7DL \
 *     --services-id com.anuragrishi.knowthyself.signin
 */
import { createSign } from "node:crypto";
import { readFileSync } from "node:fs";

function arg(name) {
  const i = process.argv.indexOf(`--${name}`);
  return i === -1 ? undefined : process.argv[i + 1];
}

const keyPath = arg("key");
const keyId = arg("key-id");
const teamId = arg("team-id");
const servicesId = arg("services-id");

if (!keyPath || !keyId || !teamId || !servicesId) {
  console.error(
    "Usage: node scripts/apple-client-secret.mjs --key <AuthKey_XXX.p8> " +
      "--key-id <KEY_ID> --team-id <TEAM_ID> --services-id <SERVICES_ID>",
  );
  process.exit(1);
}

const b64url = (buf) =>
  Buffer.from(buf)
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

const now = Math.floor(Date.now() / 1000);
// Apple caps the lifetime at six months and rejects anything longer.
// Deliberately just under, so a clock skew at either end cannot push it
// over the limit and have Apple refuse the whole secret.
const SIX_MONTHS = 15777000 - 3600;

const header = { alg: "ES256", kid: keyId, typ: "JWT" };
const payload = {
  iss: teamId,
  iat: now,
  exp: now + SIX_MONTHS,
  aud: "https://appleid.apple.com",
  sub: servicesId,
};

const signingInput = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(payload))}`;

// dsaEncoding matters: JWT wants the raw 64-byte r||s pair (P1363), and
// Node defaults to DER. A DER signature here produces a token that looks
// perfectly well-formed and that Apple rejects without explanation.
const signature = createSign("SHA256")
  .update(signingInput)
  .sign({ key: readFileSync(keyPath, "utf8"), dsaEncoding: "ieee-p1363" });

console.log(`${signingInput}.${b64url(signature)}`);
console.error(
  `\nExpires ${new Date((now + SIX_MONTHS) * 1000).toDateString()} — ` +
    `Apple's maximum. Sign-in breaks that day unless it is regenerated.\n`,
);
