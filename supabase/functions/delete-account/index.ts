// Edge Function: delete-account
//
// Deletes the calling user's own account. Required by App Store
// Guideline 5.1.1(v): an app that creates accounts must let somebody
// delete theirs from inside the app, not by writing an email.
//
// Needs the service role, because deleting an auth user is not something
// a user's own JWT can do — which is exactly why this cannot be an RPC
// and has to be a function holding a key.
//
// The identity is what gets destroyed. profiles cascades from auth.users,
// and history, downloads, devices, push tokens and chat all cascade from
// profiles. Purchases and registrations deliberately do not: migration
// 20260801000018 changed those to ON DELETE SET NULL so the financial
// record survives with its billing name and amount, pointing at nobody.
//
// Deployed with: supabase functions deploy delete-account
// verify_jwt stays ON — the caller must be a real signed-in user.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { handlePreflight, jsonResponse } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: "Missing Authorization header" }, 401);
  }

  // Identify the caller with THEIR token, never with an id from the
  // body. A user id in a request body is a request to delete somebody
  // else's account.
  const asUser = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: userData, error: userError } = await asUser.auth.getUser();
  if (userError || !userData.user) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }
  const userId = userData.user.id;

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Staff accounts are refused. An admin deleting themselves through the
  // app would lock the dashboard out with no way back, and a support
  // request is the right route for a staff departure anyway.
  const { data: profile } = await admin
    .from("profiles")
    .select("role")
    .eq("id", userId)
    .maybeSingle<{ role: string | null }>();

  if (profile?.role && profile.role !== "user") {
    return jsonResponse({
      error:
        "Staff accounts cannot be deleted from the app. Please contact " +
        "the team.",
    }, 403);
  }

  // Recorded before the deletion, because afterwards there is nothing
  // left to ask. Counts only — see the table's comment on why it holds
  // nothing that identifies anybody.
  const { count: purchaseCount } = await admin
    .from("course_purchases")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("status", "paid");

  const { count: registrationCount } = await admin
    .from("workshop_registrations")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("status", "paid");

  // Push tokens are deleted explicitly rather than left to the cascade.
  // They are the one thing that keeps reaching a physical handset after
  // the account is gone, and a failed cascade would mean notifications
  // arriving for an account that no longer exists.
  const { error: tokenError } = await admin
    .from("push_tokens")
    .delete()
    .eq("user_id", userId);

  if (tokenError) {
    console.error("Could not clear push tokens:", tokenError.message);
    return jsonResponse({ error: "Could not delete the account." }, 500);
  }

  const { error: deleteError } = await admin.auth.admin.deleteUser(userId);

  if (deleteError) {
    console.error("Account deletion failed:", deleteError.message);
    return jsonResponse({ error: "Could not delete the account." }, 500);
  }

  // After the delete, so a failed deletion never leaves a record saying
  // somebody left when they did not.
  await admin.from("account_deletions").insert({
    requested_by: "user",
    had_purchases: (purchaseCount ?? 0) + (registrationCount ?? 0) > 0,
  });

  console.log(`Account deleted: ${userId}`);
  return jsonResponse({ ok: true });
});
