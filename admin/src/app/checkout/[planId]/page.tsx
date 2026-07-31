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

  if (payload.kind === "course") {
    const { data: course } = await db
      .from("courses")
      .select("id, title, description, price_amount, currency, seat_limit, status")
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

    title = course.title;
    description = course.description;
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
    <div className="flex min-h-screen items-center justify-center bg-background p-4">
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle>{title}</CardTitle>
        </CardHeader>
        <CardContent>
          {description && (
            <p className="mb-4 text-sm text-muted-foreground">{description}</p>
          )}
          <p className="mb-2 text-3xl font-bold">{priceLabel}</p>
          {seatsLeft !== null && (
            <p className="mb-4 text-sm font-medium text-amber-600">
              Only {seatsLeft} {seatsLeft === 1 ? "seat" : "seats"} left
            </p>
          )}
          <div className="mb-2" />
          <CheckoutClient
            token={token}
            planName={title}
            defaultName={defaultName}
            defaultEmail={defaultEmail}
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
    <div className="flex min-h-screen items-center justify-center bg-background p-4">
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle>Checkout unavailable</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-muted-foreground">{message}</p>
        </CardContent>
      </Card>
    </div>
  );
}
