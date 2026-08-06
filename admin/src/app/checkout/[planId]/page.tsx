import { createAdminClient } from "@/lib/supabase/admin";
import { verifyCheckoutToken } from "@/lib/checkout-token";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { CheckoutClient } from "./checkout-client";

export const dynamic = "force-dynamic";

interface CourseRow {
  id: string;
  title: string;
  description: string | null;
  price_amount: number;
  currency: string;
  seat_limit: number | null;
  status: string;
  cover_image_url: string | null;
}

/** A paid workshop is a live session with a price on it. */
interface SessionRow {
  id: string;
  title: string;
  description: string | null;
  thumbnail_url: string | null;
  price_amount: number | null;
  currency: string;
  seat_limit: number | null;
  status: string;
  starts_at: string;
}

interface PlanRow {
  id: string;
  name: string;
  description: string | null;
  price: number;
  currency: string;
  billing_interval: string;
}

export default async function CheckoutPage({
  params,
  searchParams,
}: {
  params: Promise<{ planId: string }>;
  searchParams: Promise<{ token?: string }>;
}) {
  const { planId } = await params;
  const { token } = await searchParams;

  if (!token) {
    return <ErrorCard message="Missing checkout link. Please try again from the app." />;
  }

  const payload = verifyCheckoutToken(token);
  if (!payload || payload.tid !== planId) {
    return (
      <ErrorCard message="This link has expired or is invalid. Please go back to the app and tap 'Get Access Now' again." />
    );
  }

  const db = createAdminClient();

  // The route param is a plan id or a course id depending on what the
  // token was minted for — the token's `kind` decides, never the URL.
  let title: string;
  let description: string | null;
  let priceLabel: string;
  let seatsLeft: number | null = null;
  let coverUrl: string | null = null;
  let priceAmount: number | undefined;
  let lessonCount = 0;
  // Opened once payment is confirmed so the buyer lands back in the app
  // instead of being stranded on this page. The destination must sit in
  // the PATH, not the host — go_router routes on the path, so
  // meditationapp://payment-success?... resolves to "/" and matches
  // nothing. Handled by the /payment-success route in the mobile app.
  // Subscriptions don't have a "go straight to X" destination yet, so
  // only course checkout gets one.
  const returnUrl =
    payload.kind === "course"
      ? `meditationapp://app/payment-success?course_id=${planId}`
      : payload.kind === "workshop"
        ? "meditationapp://app/payment-success"
        : undefined;

  if (payload.kind === "workshop") {
    const { data: session } = await db
      .from("live_sessions")
      .select(
        "id, title, description, thumbnail_url, price_amount, currency, seat_limit, status, starts_at",
      )
      .eq("id", planId)
      .maybeSingle<SessionRow>();

    if (!session || session.status !== "scheduled") {
      return <ErrorCard message="This session is no longer open." />;
    }
    if (!session.price_amount || session.price_amount <= 0) {
      return <ErrorCard message="This session is free to join — no payment is needed." />;
    }
    // A session that has already started cannot be joined by somebody who
    // is only now paying for it, and taking the money anyway is worse
    // than refusing it.
    if (new Date(session.starts_at) < new Date()) {
      return <ErrorCard message="This session has already started." />;
    }

    // Already registered: taking a second payment for the same seat is
    // never what the person meant, and the unique index would reject the
    // second grant anyway — better to say so before charging.
    const { data: existing } = await db
      .from("workshop_registrations")
      .select("id")
      .eq("user_id", payload.uid)
      .eq("live_session_id", session.id)
      .eq("status", "paid")
      .maybeSingle();

    if (existing) {
      return <ErrorCard message="You are already registered for this session." />;
    }

    if (session.seat_limit !== null) {
      const { data: taken } = await db.rpc("live_session_seats_taken", {
        p_session_id: session.id,
      });
      seatsLeft = Math.max(0, session.seat_limit - (taken ?? 0));
      if (seatsLeft === 0) {
        return <ErrorCard message="This session is full." />;
      }
    }

    title = session.title;
    description = session.description;
    coverUrl = session.thumbnail_url;
    priceAmount = session.price_amount;
    priceLabel = formatPrice(session.price_amount / 100, session.currency);
  } else if (payload.kind === "course") {
    const { data: course } = await db
      .from("courses")
      .select(
        "id, title, description, price_amount, currency, seat_limit, status, cover_image_url",
      )
      .eq("id", planId)
      .maybeSingle<CourseRow>();

    if (!course || course.status !== "published") {
      return <ErrorCard message="This course is no longer available." />;
    }

    if (course.seat_limit !== null) {
      const { count } = await db
        .from("course_purchases")
        .select("id", { count: "exact", head: true })
        .eq("course_id", course.id)
        .eq("status", "paid");
      seatsLeft = Math.max(0, course.seat_limit - (count ?? 0));

      if (seatsLeft === 0) {
        return <ErrorCard message="This course is sold out." />;
      }
    }

    // Lesson count is part of what the buyer is judging, so it belongs
    // on the page they decide from.
    const { data: modules } = await db
      .from("course_modules")
      .select("lessons(id)")
      .eq("course_id", course.id);
    lessonCount = (modules ?? []).reduce(
      (n: number, m: { lessons?: unknown[] }) => n + (m.lessons?.length ?? 0),
      0,
    );

    title = course.title;
    description = course.description;
    coverUrl = course.cover_image_url;
    priceAmount = course.price_amount;
    priceLabel = formatPrice(course.price_amount / 100, course.currency);
  } else {
    const { data: plan } = await db
      .from("subscription_plans")
      .select("id, name, description, price, currency, billing_interval")
      .eq("id", planId)
      .eq("is_active", true)
      .maybeSingle<PlanRow>();

    if (!plan) {
      return <ErrorCard message="This plan is no longer available." />;
    }

    title = plan.name;
    description = plan.description;
    priceLabel = `${formatPrice(plan.price, plan.currency)} / ${plan.billing_interval.replace("ly", "")}`;
  }

  // Prefill what we already know about this user so they type as little as
  // possible. Best-effort - a failed lookup just means an empty form.
  let defaultName = "";
  let defaultEmail = "";
  try {
    const { data: profile } = await db
      .from("profiles")
      .select("display_name")
      .eq("id", payload.uid)
      .maybeSingle<{ display_name: string | null }>();
    defaultName = profile?.display_name ?? "";

    const { data: authUser } = await db.auth.admin.getUserById(payload.uid);
    defaultEmail = authUser.user?.email ?? "";
  } catch {
    // non-fatal
  }

  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-background p-4 py-8">
      <Card className="w-full max-w-md overflow-hidden">
        {coverUrl && (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={coverUrl}
            alt=""
            className="h-40 w-full object-cover"
          />
        )}
        <CardHeader className="pb-3">
          <CardTitle className="text-xl leading-snug">{title}</CardTitle>
          <div className="flex flex-wrap items-center gap-2 pt-1">
            <span className="text-2xl font-bold text-foreground">
              {priceLabel}
            </span>
            {priceAmount !== undefined && (
              <span className="text-xs text-muted-foreground">
                one-time payment
              </span>
            )}
          </div>
          <div className="flex flex-wrap gap-2 pt-1">
            {lessonCount > 0 && (
              <span className="rounded-full bg-primary/10 px-2.5 py-1 text-xs font-medium text-primary">
                {lessonCount} {lessonCount === 1 ? "lesson" : "lessons"}
              </span>
            )}
            <span className="rounded-full bg-primary/10 px-2.5 py-1 text-xs font-medium text-primary">
              Lifetime access
            </span>
            {seatsLeft !== null && (
              <span className="rounded-full bg-amber-100 px-2.5 py-1 text-xs font-semibold text-amber-700">
                Only {seatsLeft} {seatsLeft === 1 ? "seat" : "seats"} left
              </span>
            )}
          </div>
        </CardHeader>
        <CardContent>
          {description && (
            <p className="mb-5 whitespace-pre-line text-sm leading-relaxed text-muted-foreground">
              {description}
            </p>
          )}
          <CheckoutClient
            token={token}
            planName={title}
            defaultName={defaultName}
            defaultEmail={defaultEmail}
            priceAmount={priceAmount}
            priceLabel={priceLabel}
            allowCoupon={payload.kind === "course" || payload.kind === "subscription"}
            returnUrl={returnUrl}
          />
        </CardContent>
      </Card>
    </div>
  );
}

function formatPrice(price: number, currency: string): string {
  const symbol = currency === "INR" ? "₹" : currency + " ";
  return `${symbol}${price % 1 === 0 ? price : price.toFixed(2)}`;
}

function ErrorCard({ message }: { message: string }) {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-background p-4 py-8">
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle>Checkout unavailable</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-muted-foreground">{message}</p>
        </CardContent>
      </Card>
      <LegalLinks />
    </div>
  );
}

/// Policy links, under the payment card.
///
/// Here rather than only in a site footer for two reasons: Razorpay's
/// website review looks for them on the page that takes the money, and a
/// buyer deciding whether to pay should be able to read the refund terms
/// without hunting for them.
function LegalLinks() {
  return (
    <nav className="mt-4 flex flex-wrap justify-center gap-x-4 gap-y-1 text-xs text-muted-foreground">
      <a href="/terms" className="hover:text-foreground">Terms</a>
      <a href="/privacy" className="hover:text-foreground">Privacy</a>
      <a href="/refunds" className="hover:text-foreground">Refunds</a>
      <a href="/contact" className="hover:text-foreground">Contact</a>
    </nav>
  );
}
