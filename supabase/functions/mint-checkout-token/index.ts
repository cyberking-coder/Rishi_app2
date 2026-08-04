// Edge Function: mint-checkout-token
//
// Mints a short-lived signed token identifying the caller + a subscription
// plan, for the mobile app to hand to the external web checkout page (see
// _shared/checkout_token.ts for the token format and why it exists — no
// second login is needed on the web).
//
// Deployed with: supabase functions deploy mint-checkout-token

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { handlePreflight, jsonResponse } from "../_shared/cors.ts";
import { mintCheckoutToken } from "../_shared/checkout_token.ts";

const TOKEN_TTL_SECONDS = 15 * 60; // 15 minutes — long enough to open a
// browser and complete checkout, short enough to limit a leaked link's use.

interface Body {
  plan_id?: string;
  /** Set instead of plan_id to buy a single course. */
  course_id?: string;
  /** Set instead of either to register for a paid workshop, which is
   *  described by the pop-up that advertises it. */
  popup_id?: string;
}

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

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData.user) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  let body: Body;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  // A workshop is described by the pop-up that advertises it, so the
  // token targets an app_popups.id. Checked here for a price as well as
  // for existence: minting a token for a free or disabled pop-up would
  // send somebody to a checkout page with nothing to charge.
  if (body.popup_id) {
    const { data: popup, error: popupError } = await supabase
      .from("app_popups")
      .select("id, price_amount, enabled")
      .eq("id", body.popup_id)
      .eq("enabled", true)
      .maybeSingle();

    if (popupError || !popup) {
      return jsonResponse({ error: "Workshop not found" }, 404);
    }
    if (!popup.price_amount || popup.price_amount <= 0) {
      return jsonResponse(
        { error: "This workshop is not open for paid registration." },
        400,
      );
    }

    const workshopToken = await mintCheckoutToken(
      { uid: userData.user.id, kind: "workshop", tid: popup.id },
      TOKEN_TTL_SECONDS,
    );
    return jsonResponse({
      token: workshopToken,
      expires_in_seconds: TOKEN_TTL_SECONDS,
    });
  }

  // Courses are sold individually; a course token targets a courses.id
  // and the web checkout prices it from that row.
  if (body.course_id) {
    const { data: course, error: courseError } = await supabase
      .from("courses")
      .select("id")
      .eq("id", body.course_id)
      .eq("status", "published")
      .maybeSingle();

    if (courseError || !course) {
      return jsonResponse({ error: "Course not found" }, 404);
    }

    const courseToken = await mintCheckoutToken(
      { uid: userData.user.id, kind: "course", tid: course.id },
      TOKEN_TTL_SECONDS,
    );
    return jsonResponse({
      token: courseToken,
      expires_in_seconds: TOKEN_TTL_SECONDS,
    });
  }

  if (!body.plan_id) {
    return jsonResponse(
      { error: "plan_id, course_id or popup_id is required" },
      400,
    );
  }

  const { data: plan, error: planError } = await supabase
    .from("subscription_plans")
    .select("id")
    .eq("id", body.plan_id)
    .eq("is_active", true)
    .maybeSingle();

  if (planError || !plan) {
    return jsonResponse({ error: "Plan not found" }, 404);
  }

  const token = await mintCheckoutToken(
    { uid: userData.user.id, kind: "subscription", tid: plan.id },
    TOKEN_TTL_SECONDS,
  );

  return jsonResponse({ token, expires_in_seconds: TOKEN_TTL_SECONDS });
});
