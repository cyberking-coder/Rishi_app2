"use client";

import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { deactivateDevice } from "@/app/actions/devices";

export function DeactivateDeviceButton({ deviceId }: { deviceId: string }) {
  const router = useRouter();

  async function onClick() {
    const result = await deactivateDevice(deviceId);
    if (!result.ok) return toast.error(result.error);
    toast.success("Device deactivated");
    router.refresh();
  }

  return (
    <Button variant="outline" size="sm" onClick={onClick}>
      Reset
    </Button>
  );
}
