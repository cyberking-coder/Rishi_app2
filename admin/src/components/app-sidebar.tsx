"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import {
  LayoutDashboard,
  Users,
  Smartphone,
  Film,
  Music,
  GraduationCap,
  Tags,
  BarChart3,
  Settings,
  LogOut,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { createClient } from "@/lib/supabase/client";
import { Button } from "@/components/ui/button";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";

const NAV = [
  { href: "/", label: "Dashboard", icon: LayoutDashboard },
  { href: "/users", label: "Users", icon: Users },
  { href: "/devices", label: "Devices", icon: Smartphone },
  { href: "/videos", label: "Videos", icon: Film },
  { href: "/audios", label: "Audios", icon: Music },
  { href: "/courses", label: "Courses", icon: GraduationCap },
  { href: "/categories", label: "Categories", icon: Tags },
  { href: "/analytics", label: "Analytics", icon: BarChart3 },
  { href: "/settings", label: "Settings", icon: Settings },
];

export function AppSidebar({
  email,
  displayName,
}: {
  email: string;
  displayName: string | null;
}) {
  const pathname = usePathname();
  const router = useRouter();

  async function logout() {
    const supabase = createClient();
    await supabase.auth.signOut();
    router.push("/login");
    router.refresh();
  }

  const initial = (displayName ?? email).slice(0, 1).toUpperCase();

  return (
    <aside className="flex h-screen w-64 shrink-0 flex-col border-r bg-card">
      <div className="flex h-14 items-center gap-2 border-b px-6">
        <span className="text-lg font-bold tracking-tight">
          OTT<span className="text-primary"> Admin</span>
        </span>
      </div>

      <nav className="flex-1 space-y-1 p-3">
        {NAV.map((item) => {
          const active =
            item.href === "/"
              ? pathname === "/"
              : pathname.startsWith(item.href);
          const Icon = item.icon;
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                "flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors",
                active
                  ? "bg-primary/10 text-primary"
                  : "text-muted-foreground hover:bg-accent hover:text-foreground",
              )}
            >
              <Icon className="h-4 w-4" />
              {item.label}
            </Link>
          );
        })}
      </nav>

      <div className="border-t p-3">
        <div className="flex items-center gap-3 px-2 py-2">
          <Avatar>
            <AvatarFallback>{initial}</AvatarFallback>
          </Avatar>
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-medium">
              {displayName ?? "Admin"}
            </p>
            <p className="truncate text-xs text-muted-foreground">{email}</p>
          </div>
        </div>
        <Button
          variant="ghost"
          className="mt-1 w-full justify-start text-muted-foreground"
          onClick={logout}
        >
          <LogOut className="h-4 w-4" />
          Log out
        </Button>
      </div>
    </aside>
  );
}
