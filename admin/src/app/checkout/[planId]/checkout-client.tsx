"use client";

import { useEffect, useState } from "react";
import Script from "next/script";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { NativeOption, NativeSelect } from "@/components/ui/native-select";
import { appLinks } from "@/lib/legal";

// This component collects billing details, then hands off to Razorpay's
// own hosted checkout and shows a friendly "we've got it" message
// afterward. It does NOT grant access itself — that only ever happens
// server-side, in razorpay-webhook, once Razorpay confirms the payment
// out-of-band. Never trust this component's success state as proof of
// payment.

declare global {
  interface Window {
    Razorpay: new (options: Record<string, unknown>) => {
      open: () => void;
    };
  }
}

const INDIAN_STATES = [
  "Andaman and Nicobar Islands", "Andhra Pradesh", "Arunachal Pradesh",
  "Assam", "Bihar", "Chandigarh", "Chhattisgarh",
  "Dadra and Nagar Haveli and Daman and Diu", "Delhi", "Goa", "Gujarat",
  "Haryana", "Himachal Pradesh", "Jammu and Kashmir", "Jharkhand",
  "Karnataka", "Kerala", "Ladakh", "Lakshadweep", "Madhya Pradesh",
  "Maharashtra", "Manipur", "Meghalaya", "Mizoram", "Nagaland", "Odisha",
  "Puducherry", "Punjab", "Rajasthan", "Sikkim", "Tamil Nadu", "Telangana",
  "Tripura", "Uttar Pradesh", "Uttarakhand", "West Bengal", "Outside India",
];

type Status = "idle" | "loading" | "processing" | "done" | "error";

function formatPaise(paise: number): string {
  const rupees = paise / 100;
  return `₹${rupees % 1 === 0 ? rupees : rupees.toFixed(2)}`;
}

/**
 * Rewrites `meditationapp://app/…` as `intent://app/…#Intent;…;end`.
 *
 * Chrome on Android interrupts a bare custom-scheme navigation with an
 * "Open Know Thyself?" confirmation — an extra tap the buyer shouldn't
 * have to make right after paying. An intent:// URI is the form Chrome
 * resolves itself, so it hands off to the app directly.
 *
 * No `package=` component on purpose: the debug build installs under
 * com.knowthyself.app.debug, so pinning the release id would break the
 * hand-off on exactly the build being tested. Matching on scheme alone
 * covers both. No browser_fallback_url either — the only page to fall
 * back to is this one, and reloading it would drop the buyer back on an
 * empty checkout form as if they hadn't just paid.
 */
function androidIntentUrl(url: string): string {
  const separator = url.indexOf("://");
  if (separator === -1) return url;
  const scheme = url.slice(0, separator);
  const rest = url.slice(separator + 3);
  return `intent://${rest}#Intent;scheme=${scheme};end`;
}

export function CheckoutClient({
  token,
  planName,
  defaultName,
  defaultEmail,
  /** Course price in paise. Undefined for subscription checkout, where
   *  the price is a recurring plan rather than a discountable total. */
  priceAmount,
  priceLabel,
  allowCoupon = false,
  returnUrl,
  fromStore = false,
}: {
  token: string;
  planName: string;
  defaultName: string;
  defaultEmail: string;
  priceAmount?: number;
  /** Display price for the button when there's no discountable total —
   *  a subscription's "₹199 / month" rather than a one-off amount. */
  priceLabel?: string;
  allowCoupon?: boolean;
  /** meditationapp:// link opened once payment is confirmed, so the
   *  buyer returns to the app instead of being stranded on this page. */
  returnUrl?: string;
  /** True when the buyer came from the public storefront rather than
   *  the app. They may not have installed it yet — which is the whole
   *  reason the storefront exists — so the confirmation tells them how
   *  to get it and which email to use, instead of "return to the app". */
  fromStore?: boolean;
}) {
  const [status, setStatus] = useState<Status>("idle");
  const [error, setError] = useState<string | null>(null);
  const [scriptReady, setScriptReady] = useState(false);

  const [name, setName] = useState(defaultName);
  const [phone, setPhone] = useState("");
  const [email, setEmail] = useState(defaultEmail);
  const [state, setState] = useState("");

  const [couponInput, setCouponInput] = useState("");
  const [couponBusy, setCouponBusy] = useState(false);
  const [couponError, setCouponError] = useState<string | null>(null);
  const [applied, setApplied] = useState<{
    code: string;
    discount: number;
    final: number;
  } | null>(null);

  const busy = status === "loading" || status === "processing";

  // Resolved after mount, never during render: the Android variant
  // depends on the user agent, and computing it inline would make the
  // server and client markup disagree.
  const [appUrl, setAppUrl] = useState(returnUrl);
  useEffect(() => {
    if (!returnUrl) return;
    if (/Android/i.test(navigator.userAgent)) {
      setAppUrl(androidIntentUrl(returnUrl));
    }
  }, [returnUrl]);

  // Best-effort automatic return to the app once payment is confirmed.
  // Not guaranteed to fire — some mobile browsers refuse a programmatic
  // navigation to a custom scheme without a fresh user gesture — which is
  // why the "done" state below also renders a tappable fallback link
  // pointing at the same URL.
  useEffect(() => {
    if (status !== "done" || !appUrl) return;
    const timer = setTimeout(() => {
      window.location.href = appUrl;
    }, 800);
    return () => clearTimeout(timer);
  }, [status, appUrl]);
  const payable = applied?.final ?? priceAmount;

  function validate(): string | null {
    if (!name.trim()) return "Please enter your name.";
    if (!/^\+?[0-9]{10,15}$/.test(phone.replace(/\s|-/g, ""))) {
      return "Please enter a valid phone number.";
    }
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email.trim())) {
      return "Please enter a valid email address.";
    }
    if (!state) return "Please select your state.";
    return null;
  }

  async function applyCoupon() {
    if (!couponInput.trim()) return;
    setCouponBusy(true);
    setCouponError(null);
    try {
      const res = await fetch("/api/checkout/apply-coupon", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ token, coupon: couponInput }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error ?? "That code isn't valid.");

      setApplied({
        code: data.code,
        discount: data.discount_amount,
        final: data.final_amount,
      });
    } catch (e) {
      setApplied(null);
      setCouponError(e instanceof Error ? e.message : "That code isn't valid.");
    } finally {
      setCouponBusy(false);
    }
  }

  async function startCheckout(e: React.FormEvent) {
    e.preventDefault();
    const validationError = validate();
    if (validationError) {
      setError(validationError);
      return;
    }

    setStatus("loading");
    setError(null);
    try {
      const res = await fetch("/api/checkout/create-order", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          token,
          name,
          phone,
          email,
          state,
          coupon: applied?.code,
        }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error ?? "Could not start checkout");

      // A 100%-off coupon leaves nothing to pay — access was granted
      // server-side, so there's no gateway step at all.
      if (data.free) {
        setStatus("done");
        return;
      }

      const rzp = new window.Razorpay({
        key: data.key_id,
        amount: data.amount,
        currency: data.currency,
        name: "Know Thyself",
        description: planName,
        order_id: data.order_id,
        // Saves the user re-typing what they just gave us.
        prefill: data.prefill,
        // Carries our sage into Razorpay's own modal so the handoff
        // doesn't look like it landed on a different company's site.
        theme: { color: "#5F8D7E" },
        handler: () => setStatus("done"),
        modal: { ondismiss: () => setStatus("idle") },
      });
      setStatus("processing");
      rzp.open();
    } catch (e) {
      setStatus("error");
      setError(e instanceof Error ? e.message : "Something went wrong");
    }
  }

  if (status === "done") {
    return (
      <div className="rounded-2xl bg-primary/5 p-6 text-center">
        <div className="mx-auto mb-3 flex h-12 w-12 items-center justify-center rounded-full bg-primary/15 text-2xl">
          🎉
        </div>
        <p className="mb-1 font-semibold">Payment received</p>

        {fromStore ? (
          <>
            <p className="text-sm text-muted-foreground">
              Your access is being activated — this usually takes just a few
              seconds. Open the Know Thyself app and sign in with{" "}
              <span className="font-medium text-foreground">
                {email.trim()}
              </span>{" "}
              and it will be waiting for you.
            </p>
            <div className="mt-4 space-y-2">
              {appLinks.appStore && (
                <Button asChild className="w-full" size="lg">
                  <a href={appLinks.appStore}>Download for iPhone</a>
                </Button>
              )}
              <Button
                asChild
                className="w-full"
                size="lg"
                variant={appLinks.appStore ? "outline" : "default"}
              >
                <a href={appLinks.play}>Download for Android</a>
              </Button>
            </div>
            <p className="mt-4 text-xs text-muted-foreground">
              Already have the app? Just sign in — there is nothing else to do.
            </p>
          </>
        ) : (
          <>
            <p className="text-sm text-muted-foreground">
              Your access is being activated — this usually takes just a few
              seconds.
              {returnUrl
                ? " You'll be taken back to the app automatically."
                : " Return to the app and it should unlock automatically."}
            </p>
            {appUrl && (
              <Button asChild className="mt-4 w-full" size="lg">
                {/* A real user tap here also satisfies browsers that block a
                    programmatic redirect to a custom scheme without one. */}
                <a href={appUrl}>Return to the app</a>
              </Button>
            )}
          </>
        )}
      </div>
    );
  }

  return (
    <form onSubmit={startCheckout}>
      <Script
        src="https://checkout.razorpay.com/v1/checkout.js"
        onReady={() => setScriptReady(true)}
      />

      {allowCoupon && (
        <div className="mb-5">
          <Label htmlFor="co-coupon">Have a coupon?</Label>
          <div className="flex gap-2">
            <Input
              id="co-coupon"
              value={couponInput}
              onChange={(e) => {
                setCouponInput(e.target.value.toUpperCase());
                setApplied(null);
                setCouponError(null);
              }}
              placeholder="Enter code"
              disabled={busy || couponBusy}
              className="uppercase"
            />
            <Button
              type="button"
              variant="outline"
              onClick={applyCoupon}
              disabled={busy || couponBusy || !couponInput.trim()}
            >
              {couponBusy ? "Checking…" : "Apply"}
            </Button>
          </div>
          {couponError && (
            <p className="mt-1 text-xs text-destructive">{couponError}</p>
          )}
          {applied && (
            <p className="mt-1 text-xs font-medium text-primary">
              {applied.code} applied — {formatPaise(applied.discount)} off
            </p>
          )}
        </div>
      )}

      {priceAmount !== undefined && (
        <div className="mb-5 space-y-1.5 rounded-2xl bg-muted/50 p-4 text-sm">
          <div className="flex justify-between text-muted-foreground">
            <span>Course</span>
            <span>{formatPaise(priceAmount)}</span>
          </div>
          {applied && applied.discount > 0 && (
            <div className="flex justify-between text-primary">
              <span>Discount ({applied.code})</span>
              <span>−{formatPaise(applied.discount)}</span>
            </div>
          )}
          <div className="flex justify-between border-t pt-1.5 text-base font-bold">
            <span>Total</span>
            <span>{formatPaise(payable ?? priceAmount)}</span>
          </div>
        </div>
      )}

      <p className="mb-3 text-sm font-semibold">Billing information</p>

      <div className="space-y-3">
        <div>
          <Label htmlFor="co-name">Name</Label>
          <Input
            id="co-name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Your full name"
            autoComplete="name"
            disabled={busy}
          />
        </div>

        <div>
          <Label htmlFor="co-phone">Phone</Label>
          <Input
            id="co-phone"
            type="tel"
            inputMode="tel"
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            placeholder="10-digit mobile number"
            autoComplete="tel"
            disabled={busy}
          />
          <p className="mt-1 text-xs text-muted-foreground">
            We&apos;ll send your confirmation on WhatsApp to this number.
          </p>
        </div>

        <div>
          <Label htmlFor="co-email">Email</Label>
          <Input
            id="co-email"
            type="email"
            inputMode="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="you@example.com"
            autoComplete="email"
            disabled={busy}
          />
        </div>

        <div>
          <Label htmlFor="co-state">State</Label>
          <NativeSelect
            id="co-state"
            value={state}
            onChange={(e) => setState(e.target.value)}
            disabled={busy}
          >
            <NativeOption value="">Select your state</NativeOption>
            {INDIAN_STATES.map((s) => (
              <NativeOption key={s} value={s}>
                {s}
              </NativeOption>
            ))}
          </NativeSelect>
        </div>
      </div>

      <Button
        type="submit"
        className="mt-5 w-full"
        size="lg"
        disabled={!scriptReady || busy}
      >
        {busy
          ? "Opening payment…"
          : payable === 0
            ? "Get free access"
            : payable !== undefined
              ? `Pay ${formatPaise(payable)}`
              : priceLabel
                ? `Pay ${priceLabel}`
                : "Proceed to pay"}
      </Button>

      <p className="mt-3 text-center text-xs text-muted-foreground">
        Secure payment via Razorpay · UPI, cards, netbanking
      </p>

      {error && (
        <p className="mt-3 text-center text-sm text-destructive">{error}</p>
      )}
    </form>
  );
}
