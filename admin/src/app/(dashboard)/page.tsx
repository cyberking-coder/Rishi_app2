import { Users, Smartphone, Film, Music, Eye, Headphones } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { PageHeader } from "@/components/page-header";
import { StatCard } from "@/components/stat-card";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { ContentStatusBadge } from "@/components/status-badge";
import { formatDate, formatNumber } from "@/lib/utils";
import type { Video } from "@/lib/types";

export const dynamic = "force-dynamic";

async function count(
  table: string,
  eq?: { column: string; value: string | boolean },
): Promise<number> {
  const supabase = createClient();
  const query = supabase
    .from(table)
    .select("*", { count: "exact", head: true });
  const { count: c } = eq ? await query.eq(eq.column, eq.value) : await query;
  return c ?? 0;
}

export default async function DashboardPage() {
  const supabase = createClient();

  const [users, activeDevices, videos, audios] = await Promise.all([
    count("profiles"),
    count("devices", { column: "is_active", value: true }),
    count("videos", { column: "status", value: "published" }),
    count("audios", { column: "status", value: "published" }),
  ]);

  const { data: viewAgg } = await supabase
    .from("videos")
    .select("view_count");
  const totalViews = (viewAgg ?? []).reduce(
    (sum, row) => sum + ((row as { view_count: number }).view_count ?? 0),
    0,
  );

  const { data: playAgg } = await supabase.from("audios").select("play_count");
  const totalPlays = (playAgg ?? []).reduce(
    (sum, row) => sum + ((row as { play_count: number }).play_count ?? 0),
    0,
  );

  const { data: recent } = await supabase
    .from("videos")
    .select("id, title, status, view_count, created_at")
    .order("created_at", { ascending: false })
    .limit(5)
    .returns<Pick<Video, "id" | "title" | "status" | "view_count" | "created_at">[]>();

  return (
    <div>
      <PageHeader
        title="Dashboard"
        description="Platform overview and recent activity."
      />

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <StatCard title="Total Users" value={formatNumber(users)} icon={Users} />
        <StatCard
          title="Active Devices"
          value={formatNumber(activeDevices)}
          icon={Smartphone}
          hint="One active device per account"
        />
        <StatCard
          title="Published Videos"
          value={formatNumber(videos)}
          icon={Film}
        />
        <StatCard
          title="Published Audios"
          value={formatNumber(audios)}
          icon={Music}
        />
        <StatCard
          title="Total Video Views"
          value={formatNumber(totalViews)}
          icon={Eye}
        />
        <StatCard
          title="Total Audio Plays"
          value={formatNumber(totalPlays)}
          icon={Headphones}
        />
      </div>

      <Card className="mt-6">
        <CardHeader>
          <CardTitle>Recently added videos</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          {(recent ?? []).length === 0 ? (
            <p className="text-sm text-muted-foreground">No videos yet.</p>
          ) : (
            (recent ?? []).map((v) => (
              <div
                key={v.id}
                className="flex items-center justify-between border-b pb-3 last:border-0 last:pb-0"
              >
                <div>
                  <p className="font-medium">{v.title}</p>
                  <p className="text-xs text-muted-foreground">
                    {formatDate(v.created_at)} · {formatNumber(v.view_count)} views
                  </p>
                </div>
                <ContentStatusBadge status={v.status} />
              </div>
            ))
          )}
        </CardContent>
      </Card>
    </div>
  );
}
