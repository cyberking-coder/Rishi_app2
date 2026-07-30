"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { RefreshCw } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { refreshBunnyStatus } from "@/app/actions/content";
import type { Video } from "@/lib/types";

/**
 * Bunny transcode state, with a manual refresh.
 *
 * Bunny has no webhook wired up, so nothing tells us when encoding
 * finishes — the button polls on demand. Auto-polling every row on an
 * interval would burn API calls on videos that finished days ago.
 */
export function BunnyStatusCell({
  videoId,
  bunnyVideoId,
  bunnyStatus,
}: {
  videoId: string;
  bunnyVideoId: string | null;
  bunnyStatus: Video["bunny_status"];
}) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);

  if (!bunnyVideoId) {
    return (
      <Badge variant="outline" title="Plays from R2 as a single file">
        Direct
      </Badge>
    );
  }

  async function refresh() {
    setBusy(true);
    try {
      const result = await refreshBunnyStatus(videoId);
      if (!result.ok) return toast.error(result.error);
      router.refresh();
    } finally {
      setBusy(false);
    }
  }

  const badge =
    bunnyStatus === "ready" ? (
      <Badge variant="success">Ready</Badge>
    ) : bunnyStatus === "failed" ? (
      <Badge variant="destructive">Failed</Badge>
    ) : (
      <Badge variant="warning">Encoding</Badge>
    );

  return (
    <div className="flex items-center gap-1">
      {badge}
      {bunnyStatus !== "ready" && (
        <Button
          variant="ghost"
          size="icon"
          className="h-6 w-6"
          disabled={busy}
          onClick={refresh}
          title="Check encoding progress"
        >
          <RefreshCw className={busy ? "h-3 w-3 animate-spin" : "h-3 w-3"} />
        </Button>
      )}
    </div>
  );
}
