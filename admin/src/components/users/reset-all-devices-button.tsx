"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Smartphone } from "lucide-react";
import { resetAllDevices } from "@/app/actions/devices";
import { Button } from "@/components/ui/button";

/** Bulk device-lock reset. Asks for confirmation, then deactivates every
 *  active device so all users can re-register on next login. */
export function ResetAllDevicesButton() {
  const router = useRouter();
  const [busy, setBusy] = useState(false);

  async function run() {
    const ok = window.confirm(
      "Reset the device lock for ALL users?\n\n" +
        "Every account's current device will be unlinked and their offline " +
        "downloads revoked. Each user will be able to sign in on a new device. " +
        "Use this after shipping a new app build.",
    );
    if (!ok) return;

    setBusy(true);
    const result = await resetAllDevices();
    setBusy(false);
    if (!result.ok) return toast.error(result.error);
    toast.success(`Reset ${result.count} device${result.count === 1 ? "" : "s"}`);
    router.refresh();
  }

  return (
    <Button variant="outline" onClick={run} disabled={busy}>
      <Smartphone className="mr-2 h-4 w-4" />
      {busy ? "Resetting…" : "Reset all devices"}
    </Button>
  );
}
