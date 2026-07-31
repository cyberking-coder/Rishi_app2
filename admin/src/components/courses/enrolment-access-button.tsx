"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { setCourseEnrolmentAccess } from "@/app/actions/courses";

/**
 * Take a student's access to this course away, or give it back.
 *
 * Revoking is destructive from the student's point of view — the course
 * relocks and their lesson media stops playing — so it asks first.
 * Restoring doesn't, since it can only widen access.
 */
export function EnrolmentAccessButton({
  userId,
  courseId,
  studentLabel,
  revoked,
}: {
  userId: string;
  courseId: string;
  studentLabel: string;
  revoked: boolean;
}) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);

  async function run() {
    if (
      !revoked &&
      !window.confirm(
        `Remove ${studentLabel}'s access to this course? They keep their ` +
          `purchase record, but the course relocks in the app immediately.`,
      )
    ) {
      return;
    }

    setBusy(true);
    try {
      const result = await setCourseEnrolmentAccess(userId, courseId, !revoked);
      if (!result.ok) return toast.error(result.error);
      toast.success(revoked ? "Access restored." : "Access removed.");
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
      {revoked ? "Restore access" : "Remove access"}
    </Button>
  );
}
