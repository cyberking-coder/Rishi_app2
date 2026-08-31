import { createClient } from "@/lib/supabase/server";
import { PageHeader } from "@/components/page-header";
import { UploadContentDialog } from "@/components/content/upload-content-dialog";
import { BulkUploadAudioDialog } from "@/components/content/bulk-upload-audio-dialog";
import { ContentActions } from "@/components/content/content-actions";
import { ContentStatusBadge } from "@/components/status-badge";
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
import { formatNumber } from "@/lib/utils";
import type { Audio } from "@/lib/types";

export const dynamic = "force-dynamic";

export default async function AudiosPage() {
  const supabase = createClient();
  const { data: audios } = await supabase
    .from("audios")
    .select("id, title, artist, status, audio_type, is_premium, play_count, created_at, cover_art_url")
    .order("created_at", { ascending: false })
    .returns<Audio[]>();

  return (
    <div>
      <PageHeader
        title="Audios"
        description="Upload, publish, and manage audio content."
        action={
          <div className="flex gap-2">
            <BulkUploadAudioDialog />
            <UploadContentDialog kind="audio" />
          </div>
        }
      />

      <Card>
        <CardContent className="p-0">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead className="w-16">Cover</TableHead>
                <TableHead>Title</TableHead>
                <TableHead>Artist</TableHead>
                <TableHead>Type</TableHead>
                <TableHead>Access</TableHead>
                <TableHead>Plays</TableHead>
                <TableHead>Status</TableHead>
                <TableHead className="w-12" />
              </TableRow>
            </TableHeader>
            <TableBody>
              {(audios ?? []).length === 0 ? (
                <TableRow>
                  <TableCell colSpan={8} className="py-8 text-center text-muted-foreground">
                    No audios yet.
                  </TableCell>
                </TableRow>
              ) : (
                (audios ?? []).map((a) => (
                  <TableRow key={a.id}>
                    <TableCell>
                      {a.cover_art_url ? (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img
                          src={a.cover_art_url}
                          alt=""
                          className="h-10 w-10 rounded-md object-cover"
                        />
                      ) : (
                        <div className="flex h-10 w-10 items-center justify-center rounded-md bg-muted text-xs text-muted-foreground">
                          —
                        </div>
                      )}
                    </TableCell>
                    <TableCell className="font-medium">{a.title}</TableCell>
                    <TableCell className="text-muted-foreground">
                      {a.artist ?? "—"}
                    </TableCell>
                    <TableCell className="capitalize">
                      {a.audio_type.replace("_", " ")}
                    </TableCell>
                    <TableCell>
                      <Badge variant={a.is_premium ? "default" : "outline"}>
                        {a.is_premium ? "Premium" : "Free"}
                      </Badge>
                    </TableCell>
                    <TableCell>{formatNumber(a.play_count)}</TableCell>
                    <TableCell>
                      <ContentStatusBadge status={a.status} />
                    </TableCell>
                    <TableCell>
                      <ContentActions
                        kind="audio"
                        contentId={a.id}
                        status={a.status}
                        isPremium={a.is_premium}
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
