"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { setCertificateRevoked } from "@/app/actions/quizzes";

export function CertificateRevokeButton({
  certificateId,
  revoked,
  holder,
}: {
  certificateId: string;
  revoked: boolean;
  holder: string;
}) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);

  async function run() {
    if (
      !revoked &&
      !window.confirm(
        `Revoke ${holder}'s certificate? The number keeps resolving, but ` +
          `verification will report it as withdrawn.`,
      )
    ) {
      return;
    }

    setBusy(true);
    try {
      const result = await setCertificateRevoked(certificateId, !revoked);
      if (!result.ok) return toast.error(result.error);
      toast.success(revoked ? "Certificate reinstated." : "Certificate revoked.");
      router.refresh();
    } finally {
      setBusy(false);
    }
  }

  return (
    <Button
      variant={revoked ? "outline" : "ghost"}
      size="sm"
      disabled={busy}
      onClick={run}
      className={revoked ? undefined : "text-destructive hover:text-destructive"}
    >
      {revoked ? "Reinstate" : "Revoke"}
    </Button>
  );
}
