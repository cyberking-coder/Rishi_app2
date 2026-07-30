import { createClient } from "@/lib/supabase/server";
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
  const { data: videos } = await supabase
    .from("videos")
    .select("id, title, status, video_type, is_premium, view_count, created_at, bunny_video_id, bunny_status")
    .order("created_at", { ascending: false })
    .returns<Video[]>();

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
