"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import {
  BarChart3,
  CreditCard,
  Film,
  GraduationCap,
  LayoutDashboard,
  LifeBuoy,
  LogOut,
  Music,
  Settings,
  Smartphone,
  Tags,
  TicketPercent,
  Users,
  Youtube,
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
  { href: "/youtube", label: "YouTube", icon: Youtube },
  { href: "/plans", label: "Membership", icon: CreditCard },
  { href: "/coupons", label: "Coupons", icon: TicketPercent },
  { href: "/categories", label: "Categories", icon: Tags },
  { href: "/support", label: "Help & Support", icon: LifeBuoy },
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
    // Floats as a rounded panel inset from the canvas rather than a
    // full-bleed bordered column, so it reads as part of the same card
    // system as the content.
    <aside className="sticky top-0 flex h-screen w-60 shrink-0 flex-col p-3">
      <div className="flex flex-1 flex-col rounded-[var(--radius)] bg-card p-3 shadow-sm ring-1 ring-black/[0.04]">
        <div className="px-3 py-4">
          <span className="text-base font-semibold tracking-tight">
            Know Thyself
          </span>
          <p className="text-xs text-muted-foreground">Admin</p>
        </div>

        <nav className="flex-1 space-y-0.5">
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
                  "flex items-center gap-3 rounded-full px-3 py-2 text-sm transition-colors",
                  active
                    ? "bg-primary text-primary-foreground font-medium"
                    : "text-muted-foreground hover:bg-accent hover:text-foreground",
                )}
              >
                <Icon className="h-4 w-4 shrink-0" />
                {item.label}
              </Link>
            );
          })}
        </nav>

        <div className="mt-2 border-t pt-2">
          <div className="flex items-center gap-2 px-2 py-2">
            <Avatar className="h-8 w-8">
              <AvatarFallback className="text-xs">{initial}</AvatarFallback>
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
            className="w-full justify-start gap-3 rounded-full px-3 text-muted-foreground"
            onClick={logout}
          >
            <LogOut className="h-4 w-4" />
            Log out
          </Button>
        </div>
      </div>
    </aside>
  );
}
