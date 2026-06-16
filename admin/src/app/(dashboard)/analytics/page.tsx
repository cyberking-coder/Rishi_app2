import { createClient } from "@/lib/supabase/server";
import { PageHeader } from "@/components/page-header";
import { ViewsChart, type DailyPoint } from "@/components/analytics/views-chart";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { formatNumber } from "@/lib/utils";
import type { Audio, Video } from "@/lib/types";

export const dynamic = "force-dynamic";

interface DailyRow {
  day: string;
  total_views: number;
  total_watch_seconds: number;
}

export default async function AnalyticsPage() {
  const supabase = createClient();

  const since = new Date();
  since.setDate(since.getDate() - 30);
  const sinceStr = since.toISOString().slice(0, 10);

  const { data: daily } = await supabase
    .from("content_analytics_daily")
    .select("day, total_views, total_watch_seconds")
    .gte("day", sinceStr)
    .order("day", { ascending: true })
    .returns<DailyRow[]>();

  // Aggregate per-content daily rows into a single platform-wide series.
  const byDay = new Map<string, DailyPoint>();
  for (const row of daily ?? []) {
    const existing = byDay.get(row.day) ?? {
      day: row.day.slice(5),
      views: 0,
      watchHours: 0,
    };
    existing.views += row.total_views;
    existing.watchHours += row.total_watch_seconds / 3600;
    byDay.set(row.day, existing);
  }
  const series = Array.from(byDay.values());

  const { data: topVideos } = await supabase
    .from("videos")
    .select("id, title, view_count")
    .order("view_count", { ascending: false })
    .limit(5)
    .returns<Pick<Video, "id" | "title" | "view_count">[]>();

  const { data: topAudios } = await supabase
    .from("audios")
    .select("id, title, play_count")
    .order("play_count", { ascending: false })
    .limit(5)
    .returns<Pick<Audio, "id" | "title" | "play_count">[]>();

  return (
    <div>
      <PageHeader
        title="Analytics"
        description="Viewership trends over the last 30 days."
      />

      <Card>
        <CardHeader>
          <CardTitle>Daily views</CardTitle>
        </CardHeader>
        <CardContent>
          {series.length === 0 ? (
            <p className="py-12 text-center text-sm text-muted-foreground">
              No analytics data yet. The daily rollup populates
              `content_analytics_daily`.
            </p>
          ) : (
            <ViewsChart data={series} />
          )}
        </CardContent>
      </Card>

      <div className="mt-6 grid grid-cols-1 gap-6 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Top videos</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            {(topVideos ?? []).map((v, i) => (
              <div key={v.id} className="flex items-center justify-between">
                <span className="flex items-center gap-3">
                  <span className="text-muted-foreground">{i + 1}.</span>
                  <span className="font-medium">{v.title}</span>
                </span>
                <span className="text-sm text-muted-foreground">
                  {formatNumber(v.view_count)} views
                </span>
              </div>
            ))}
            {(topVideos ?? []).length === 0 && (
              <p className="text-sm text-muted-foreground">No videos yet.</p>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Top audios</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            {(topAudios ?? []).map((a, i) => (
              <div key={a.id} className="flex items-center justify-between">
                <span className="flex items-center gap-3">
                  <span className="text-muted-foreground">{i + 1}.</span>
                  <span className="font-medium">{a.title}</span>
                </span>
                <span className="text-sm text-muted-foreground">
                  {formatNumber(a.play_count)} plays
                </span>
              </div>
            ))}
            {(topAudios ?? []).length === 0 && (
              <p className="text-sm text-muted-foreground">No audios yet.</p>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
