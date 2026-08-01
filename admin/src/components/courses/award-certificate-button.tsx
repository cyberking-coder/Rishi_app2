"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Award } from "lucide-react";
import { Button } from "@/components/ui/button";
import { awardCertificate } from "@/app/actions/quizzes";

/**
 * Awards a certificate to one student for this course, regardless of
 * whether they finished it.
 *
 * Confirms first, and says plainly that it bypasses completion — an
 * admin should never award one by reflex, because a verifier cannot tell
 * a manual award from an earned one and shouldn't be able to.
 */
export function AwardCertificateButton({
  userId,
  courseId,
  studentLabel,
  existingNumber,
}: {
  userId: string;
  courseId: string;
  studentLabel: string;
  existingNumber?: string;
}) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);

  if (existingNumber) {
    return (
      <span
        className="inline-flex items-center gap-1 text-xs text-muted-foreground"
        title={`Certificate ${existingNumber}`}
      >
        <Award className="h-3.5 w-3.5" />
        {existingNumber}
      </span>
    );
  }

  async function run() {
    if (
      !window.confirm(
        `Award a certificate to ${studentLabel} for this course?\n\n` +
          `This skips the completion check — they do not need to have ` +
          `finished the lessons or passed the quizzes. The certificate is ` +
          `indistinguishable from an earned one when verified.`,
      )
    ) {
      return;
    }

    setBusy(true);
    try {
      const result = await awardCertificate(userId, courseId);
      if (!result.ok) return toast.error(result.error);
      toast.success(`Certificate ${result.number} awarded.`);
      router.refresh();
    } finally {
      setBusy(false);
    }
  }

  return (
    <Button variant="ghost" size="sm" disabled={busy} onClick={run}>
      <Award className="mr-1.5 h-3.5 w-3.5" />
      Award
    </Button>
  );
}
