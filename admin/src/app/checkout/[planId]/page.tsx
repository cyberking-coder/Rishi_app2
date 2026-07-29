import { createAdminClient } from "@/lib/supabase/admin";
import { verifyCheckoutToken } from "@/lib/checkout-token";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { CheckoutClient } from "./checkout-client";

export const dynamic = "force-dynamic";

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
  const { data: plan } = await db
    .from("subscription_plans")
    .select("id, name, description, price, currency, billing_interval")
    .eq("id", planId)
    .eq("is_active", true)
    .maybeSingle<PlanRow>();

  if (!plan) {
    return <ErrorCard message="This plan is no longer available." />;
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-background p-4">
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle>{plan.name}</CardTitle>
        </CardHeader>
        <CardContent>
          {plan.description && (
            <p className="mb-4 text-sm text-muted-foreground">{plan.description}</p>
          )}
          <p className="mb-6 text-3xl font-bold">
            {formatPrice(plan.price, plan.currency)}
            <span className="text-base font-normal text-muted-foreground">
              {" "}
              / {plan.billing_interval.replace("ly", "")}
            </span>
          </p>
          <CheckoutClient token={token} planName={plan.name} />
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
