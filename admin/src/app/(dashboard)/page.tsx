import Link from "next/link";
import {
  ChevronRight,
  GraduationCap,
  Headphones,
  Music,
  Smartphone,
  Users,
} from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { StatCard } from "@/components/stat-card";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent } from "@/components/ui/card";
import { formatDate, formatNumber } from "@/lib/utils";
import { resolveTier } from "@/lib/access";
import type { Audio, Profile } from "@/lib/types";

export const dynamic = "force-dynamic";

async function count(
  table: string,
  eq?: { column: string; value: string | boolean },
): Promise<number> {
  const supabase = createClient();
  const query = supabase.from(table).select("*", { count: "exact", head: true });
  const { count: c } = eq ? await query.eq(eq.column, eq.value) : await query;
  return c ?? 0;
}

function greeting(): string {
  const h = new Date().getHours();
  if (h < 12) return "Good morning";
  if (h < 17) return "Good afternoon";
  return "Good evening";
}

export default async function DashboardPage() {
  const supabase = createClient();

  const [users, activeDevices, audios, courses] = await Promise.all([
    count("profiles"),
    count("devices", { column: "is_active", value: true }),
    count("audios", { column: "status", value: "published" }),
    count("courses", { column: "status", value: "published" }),
  ]);

  const [{ data: playAgg }, { data: topAudios }, { data: recentUsers }] =
    await Promise.all([
      supabase.from("audios").select("play_count"),
      supabase
        .from("audios")
        .select("id, title, artist, cover_art_url, play_count, is_premium")
        .eq("status", "published")
        .order("play_count", { ascending: false })
        .limit(5)
        .returns<
          Pick<
            Audio,
            | "id"
            | "title"
            | "artist"
            | "cover_art_url"
            | "play_count"
            | "is_premium"
          >[]
        >(),
      supabase
        .from("profiles")
        .select("*")
        .order("created_at", { ascending: false })
        .limit(5)
        .returns<Profile[]>(),
    ]);

  const totalPlays = (playAgg ?? []).reduce(
    (sum, row) => sum + ((row as { play_count: number }).play_count ?? 0),
    0,
  );

  return (
    <div className="space-y-5">
      <div>
        <h1 className="text-3xl font-semibold tracking-tight">{greeting()}</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          Here&apos;s how Know Thyself is doing today.
        </p>
      </div>

      <div className="grid gap-4 lg:grid-cols-3">
        {/* Left: the numbers */}
        <div className="grid gap-4 sm:grid-cols-2 lg:col-span-2">
          <StatCard
            title="Total members"
            value={formatNumber(users)}
            icon={Users}
          />
          <StatCard
            title="Active devices"
            value={formatNumber(activeDevices)}
            icon={Smartphone}
            hint="One per account"
          />
          <StatCard
            title="Published audio"
            value={formatNumber(audios)}
            icon={Music}
          />
          <StatCard
            title="Published courses"
            value={formatNumber(courses)}
            icon={GraduationCap}
          />
          <StatCard
            title="Total plays"
            value={formatNumber(totalPlays)}
            icon={Headphones}
            className="sm:col-span-2"
          />
        </div>

        {/* Right: newest members */}
        <Card>
          <CardContent className="p-5">
            <div className="mb-4 flex items-center justify-between">
              <h2 className="font-medium">Newest members</h2>
              <Link
                href="/users"
                className="flex items-center gap-0.5 text-xs text-muted-foreground hover:text-foreground"
              >
                All <ChevronRight className="h-3 w-3" />
              </Link>
            </div>

            {(recentUsers ?? []).length === 0 ? (
              <p className="text-sm text-muted-foreground">No members yet.</p>
            ) : (
              <div className="space-y-3">
                {(recentUsers ?? []).map((u) => {
                  const tier = resolveTier(u);
                  return (
                    <div key={u.id} className="flex items-center gap-3">
                      <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-accent text-xs font-medium">
                        {(u.display_name ?? "?").slice(0, 1).toUpperCase()}
                      </div>
                      <div className="min-w-0 flex-1">
                        <p className="truncate text-sm">
                          {u.display_name ?? "Unnamed"}
                        </p>
                        <p className="text-xs text-muted-foreground">
                          {formatDate(u.created_at)}
                        </p>
                      </div>
                      <Badge
                        variant={tier === "free" ? "outline" : "default"}
                        className="shrink-0"
                      >
                        {tier === "admin"
                          ? "Staff"
                          : tier === "retreat"
                            ? "Premium"
                            : "Free"}
                      </Badge>
                    </div>
                  );
                })}
              </div>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Most played */}
      <Card>
        <CardContent className="p-5">
          <div className="mb-4 flex items-center justify-between">
            <h2 className="font-medium">Most played</h2>
            <Link
              href="/audios"
              className="flex items-center gap-0.5 text-xs text-muted-foreground hover:text-foreground"
            >
              All audio <ChevronRight className="h-3 w-3" />
            </Link>
          </div>

          {(topAudios ?? []).length === 0 ? (
            <p className="text-sm text-muted-foreground">
              Nothing published yet.
            </p>
          ) : (
            <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-5">
              {(topAudios ?? []).map((a) => (
                <div key={a.id}>
                  <div className="mb-2 aspect-square overflow-hidden rounded-2xl bg-accent">
                    {a.cover_art_url ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img
                        src={a.cover_art_url}
                        alt=""
                        className="h-full w-full object-cover"
                      />
                    ) : (
                      <div className="flex h-full items-center justify-center">
                        <Music className="h-6 w-6 text-muted-foreground" />
                      </div>
                    )}
                  </div>
                  <p className="truncate text-sm font-medium">{a.title}</p>
                  <p className="truncate text-xs text-muted-foreground">
                    {a.artist ?? "—"}
                  </p>
                  <p className="mt-0.5 text-xs text-muted-foreground">
                    {formatNumber(a.play_count)} plays
                  </p>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
