import { createClient } from "@/lib/supabase/server";
import { PageHeader } from "@/components/page-header";
import { AddYoutubeDialog } from "@/components/youtube/add-youtube-dialog";
import { YoutubeActions } from "@/components/youtube/youtube-actions";
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
import { formatDate } from "@/lib/utils";
import type { Category, YoutubeVideo } from "@/lib/types";

export const dynamic = "force-dynamic";

export default async function YoutubePage() {
  const supabase = createClient();

  const [{ data: videos }, { data: categories }] = await Promise.all([
    supabase
      .from("youtube_videos")
      .select("*")
      .order("sort_order", { ascending: true })
      .order("created_at", { ascending: false })
      .returns<YoutubeVideo[]>(),
    supabase
      .from("categories")
      .select("*")
      .order("name", { ascending: true })
      .returns<Category[]>(),
  ]);

  return (
    <div>
      <PageHeader
        title="YouTube"
        description="Free videos shown in the app's Watch section. These play on YouTube — nothing is hosted or streamed by us."
        action={<AddYoutubeDialog categories={categories ?? []} />}
      />

      <Card>
        <CardContent className="p-0">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead className="w-28">Thumbnail</TableHead>
                <TableHead>Title</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Added</TableHead>
                <TableHead className="w-12" />
              </TableRow>
            </TableHeader>
            <TableBody>
              {(videos ?? []).length === 0 ? (
                <TableRow>
                  <TableCell
                    colSpan={5}
                    className="py-8 text-center text-muted-foreground"
                  >
                    No videos yet. Add a YouTube link to show it in the app.
                  </TableCell>
                </TableRow>
              ) : (
                (videos ?? []).map((v) => (
                  <TableRow key={v.id}>
                    <TableCell>
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img
                        src={v.thumbnail_url ?? ""}
                        alt=""
                        className="h-12 w-20 rounded-md object-cover"
                      />
                    </TableCell>
                    <TableCell className="font-medium">
                      <a
                        href={v.youtube_url}
                        target="_blank"
                        rel="noreferrer"
                        className="hover:underline"
                      >
                        {v.title}
                      </a>
                    </TableCell>
                    <TableCell>
                      <Badge variant={v.is_published ? "success" : "outline"}>
                        {v.is_published ? "Published" : "Hidden"}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-muted-foreground">
                      {formatDate(v.created_at)}
                    </TableCell>
                    <TableCell>
                      <YoutubeActions id={v.id} isPublished={v.is_published} />
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
