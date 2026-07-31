import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { getBunnyStatus } from "@/lib/bunny";
import { PageHeader } from "@/components/page-header";
import { UploadContentDialog } from "@/components/content/upload-content-dialog";
import { ContentActions } from "@/components/content/content-actions";
import { ContentStatusBadge } from "@/components/status-badge";
import { BunnyStatusCell } from "@/components/content/bunny-status-cell";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent } from "@/components/ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { formatDate, formatNumber } from "@/lib/utils";
import type { Video } from "@/lib/types";

export const dynamic = "force-dynamic";

export default async function VideosPage() {
  const supabase = createClient();
  const [{ data: videos }, { data: assets }] = await Promise.all([
    supabase
      .from("videos")
      .select("id, title, status, video_type, is_premium, view_count, created_at, bunny_video_id, bunny_status")
      .order("created_at", { ascending: false })
      .returns<Video[]>(),
    // Which videos still have a playable R2 rendition. Without this the
    // page can't tell "uploaded before Bunny" from "upload never
    // finished" — both look like a row with no bunny_video_id.
    supabase
      .from("content_assets")
      .select("content_id")
      .eq("content_type", "video")
      .eq("status", "ready")
      .returns<{ content_id: string }[]>(),
  ]);

  const videosWithAsset = new Set((assets ?? []).map((a) => a.content_id));

  await syncEncodingStatuses(videos ?? []);

  return (
    <div>
      <PageHeader
        title="Videos"
        description="Upload, publish, and manage video content."
        action={<UploadContentDialog kind="video" />}
      />

      <Card>
        <CardContent className="p-0">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Title</TableHead>
                <TableHead>Type</TableHead>
                <TableHead>Access</TableHead>
                <TableHead>Views</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Streaming</TableHead>
                <TableHead>Added</TableHead>
                <TableHead className="w-12" />
              </TableRow>
            </TableHeader>
            <TableBody>
              {(videos ?? []).length === 0 ? (
                <TableRow>
                  <TableCell colSpan={8} className="py-8 text-center text-muted-foreground">
                    No videos yet.
                  </TableCell>
                </TableRow>
              ) : (
                (videos ?? []).map((v) => (
                  <TableRow key={v.id}>
                    <TableCell className="font-medium">{v.title}</TableCell>
                    <TableCell className="capitalize">{v.video_type}</TableCell>
                    <TableCell>
                      <Badge variant={v.is_premium ? "default" : "outline"}>
                        {v.is_premium ? "Premium" : "Free"}
                      </Badge>
                    </TableCell>
                    <TableCell>{formatNumber(v.view_count)}</TableCell>
                    <TableCell>
                      <ContentStatusBadge status={v.status} />
                    </TableCell>
                    <TableCell>
                      <BunnyStatusCell
                        videoId={v.id}
                        bunnyVideoId={v.bunny_video_id}
                        bunnyStatus={v.bunny_status}
                        hasDirectAsset={videosWithAsset.has(v.id)}
                      />
                    </TableCell>
                    <TableCell className="text-muted-foreground">
                      {formatDate(v.created_at)}
                    </TableCell>
                    <TableCell>
                      <ContentActions
                        kind="video"
                        contentId={v.id}
                        status={v.status}
                        isPremium={v.is_premium}
                      />
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </div>
  );
}

/**
 * Brings `bunny_status` up to date for anything still encoding.
 *
 * Bunny sends no webhook, so a row that was "processing" when the upload
 * finished stays "processing" in our database until someone clicks
 * Refresh — even after Bunny has been serving the video for days. That
 * stale value is what the mobile app's playback license checks, so a
 * finished video reads as unplayable. Syncing on page load means the
 * badge is truthful without anyone having to press anything.
 *
 * Only unfinished rows are polled, so a library of ready videos costs
 * nothing. Mutates the rows in place so this render shows the new state.
 */
async function syncEncodingStatuses(videos: Video[]): Promise<void> {
  const pending = videos.filter(
    (v) => v.bunny_video_id && v.bunny_status !== "ready" && v.bunny_status !== "failed",
  );
  if (pending.length === 0) return;

  const db = createAdminClient();
  await Promise.all(
    pending.map(async (v) => {
      try {
        const status = await getBunnyStatus(v.bunny_video_id!);
        if (status === v.bunny_status) return;
        v.bunny_status = status;
        await db.from("videos").update({ bunny_status: status }).eq("id", v.id);
      } catch {
        // Best-effort: a Bunny outage shouldn't take the page down. The
        // row keeps its old status and the manual Refresh button remains.
      }
    }),
  );
}
