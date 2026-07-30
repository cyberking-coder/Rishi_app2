"use client";

import { useState } from "react";
import Script from "next/script";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { NativeOption, NativeSelect } from "@/components/ui/native-select";

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

export function CheckoutClient({
  token,
  planName,
  defaultName,
  defaultEmail,
}: {
  token: string;
  planName: string;
  defaultName: string;
  defaultEmail: string;
}) {
  const [status, setStatus] = useState<Status>("idle");
  const [error, setError] = useState<string | null>(null);
  const [scriptReady, setScriptReady] = useState(false);

  const [name, setName] = useState(defaultName);
  const [phone, setPhone] = useState("");
  const [email, setEmail] = useState(defaultEmail);
  const [state, setState] = useState("");

  const busy = status === "loading" || status === "processing";

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
        body: JSON.stringify({ token, name, phone, email, state }),
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
        // Saves the user re-typing what they just gave us.
        prefill: data.prefill,
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
    <form onSubmit={startCheckout}>
      <Script
        src="https://checkout.razorpay.com/v1/checkout.js"
        onReady={() => setScriptReady(true)}
      />

      <p className="mb-3 text-sm font-medium">Billing information</p>

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
        disabled={!scriptReady || busy}
      >
        {busy ? "Opening payment…" : "Proceed to pay"}
      </Button>

      {error && <p className="mt-3 text-sm text-destructive">{error}</p>}
    </form>
  );
}
