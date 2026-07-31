"use client";

import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { MoreHorizontal } from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Button } from "@/components/ui/button";
import { deleteYoutubeVideo, setYoutubePublished } from "@/app/actions/youtube";

export function YoutubeActions({
  id,
  isPublished,
}: {
  id: string;
  isPublished: boolean;
}) {
  const router = useRouter();

  async function toggle() {
    const result = await setYoutubePublished({ id, isPublished: !isPublished });
    if (!result.ok) return toast.error(result.error);
    toast.success(isPublished ? "Hidden from the app" : "Published");
    router.refresh();
  }

  async function remove() {
    if (!confirm("Remove this video from the app?")) return;
    const result = await deleteYoutubeVideo(id);
    if (!result.ok) return toast.error(result.error);
    toast.success("Removed");
    router.refresh();
  }

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" size="icon">
          <MoreHorizontal className="h-4 w-4" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        <DropdownMenuLabel>Actions</DropdownMenuLabel>
        <DropdownMenuItem onClick={toggle}>
          {isPublished ? "Hide from app" : "Publish"}
        </DropdownMenuItem>
        <DropdownMenuSeparator />
        <DropdownMenuItem className="text-destructive" onClick={remove}>
          Delete
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
