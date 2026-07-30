"use client";

import { useState } from "react";
import Script from "next/script";
import { Button } from "@/components/ui/button";

// This component's only job is to hand off to Razorpay's own hosted
// checkout and show a friendly "we've got it" message afterward. It does
// NOT grant access itself — that only ever happens server-side, in
// razorpay-webhook, once Razorpay confirms the payment out-of-band. Never
// trust this component's success state as proof of payment.

declare global {
  interface Window {
    Razorpay: new (options: Record<string, unknown>) => {
      open: () => void;
    };
  }
}

type Status = "idle" | "loading" | "processing" | "done" | "error";

export function CheckoutClient({
  token,
  planName,
}: {
  token: string;
  planName: string;
}) {
  const [status, setStatus] = useState<Status>("idle");
  const [error, setError] = useState<string | null>(null);
  const [scriptReady, setScriptReady] = useState(false);

  async function startCheckout() {
    setStatus("loading");
    setError(null);
    try {
      const res = await fetch("/api/checkout/create-order", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ token }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error ?? "Could not start checkout");

      const rzp = new window.Razorpay({
        key: data.key_id,
        amount: data.amount,
        currency: data.currency,
        name: "Know Thyself",
        description: planName,
        order_id: data.order_id,
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
      <div className="text-center">
        <p className="mb-2 font-medium">Payment received 🎉</p>
        <p className="text-sm text-muted-foreground">
          Your access is being activated — this usually takes just a few
          seconds. Return to the app and it should unlock automatically.
        </p>
      </div>
    );
  }

  return (
    <div>
      <Script
        src="https://checkout.razorpay.com/v1/checkout.js"
        onReady={() => setScriptReady(true)}
      />
      <Button
        className="w-full"
        disabled={!scriptReady || status === "loading" || status === "processing"}
        onClick={startCheckout}
      >
        {status === "loading" ? "Starting checkout…" : "Pay now"}
      </Button>
      {error && <p className="mt-3 text-sm text-destructive">{error}</p>}
    </div>
  );
}
