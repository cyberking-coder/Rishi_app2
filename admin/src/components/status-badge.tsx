import { Badge } from "@/components/ui/badge";
import type { ContentStatus, UserStatus } from "@/lib/types";

export function ContentStatusBadge({ status }: { status: ContentStatus }) {
  const variant =
    status === "published"
      ? "success"
      : status === "processing"
        ? "warning"
        : status === "archived"
          ? "secondary"
          : "outline";
  return <Badge variant={variant}>{status}</Badge>;
}

export function UserStatusBadge({ status }: { status: UserStatus }) {
  const variant =
    status === "active"
      ? "success"
      : status === "suspended"
        ? "warning"
        : "destructive";
  return <Badge variant={variant}>{status}</Badge>;
}
