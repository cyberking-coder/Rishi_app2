"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import {
  encodeTarget,
  mintCheckoutPath,
  type BuyTarget,
} from "@/lib/checkout-link";

/**
 * Sends a buyer to the same signed checkout page the mobile app uses.
 *
 * A signed-out visitor is sent to sign in first, carrying what they were
 * trying to buy in `?buy=`, and the sign-in page resumes the purchase
 * once they are in. Dropping the intent there is how a funnel loses the
 * people who were furthest along.
 */
export function BuyButton({ target }: { target: BuyTarget }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function go() {
    setBusy(true);
    setError(null);
    try {
      const path = await mintCheckoutPath(target);
      if (!path) {
        router.push(`/store/signin?buy=${encodeURIComponent(encodeTarget(target))}`);
        return;
      }
      router.push(path);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
      setBusy(false);
    }
  }

  return (
    <div className="space-y-2">
      <Button className="w-full" onClick={go} disabled={busy}>
        {busy ? "One moment…" : "Get access"}
      </Button>
      {error && <p className="text-sm text-destructive">{error}</p>}
    </div>
  );
}
