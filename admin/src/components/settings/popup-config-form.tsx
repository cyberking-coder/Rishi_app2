"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { savePopupConfig, type PopupConfig } from "@/app/actions/config";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";

/** Converts a stored ISO timestamp to the value a datetime-local input wants
 *  (YYYY-MM-DDTHH:mm in local time), and back. */
function isoToLocalInput(iso: string | null): string {
  if (!iso) return "";
  const d = new Date(iso);
  const tzOffset = d.getTimezoneOffset() * 60000;
  return new Date(d.getTime() - tzOffset).toISOString().slice(0, 16);
}

function localInputToIso(value: string): string | null {
  if (!value) return null;
  return new Date(value).toISOString();
}

export function PopupConfigForm({ initial }: { initial: PopupConfig }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);

  const [enabled, setEnabled] = useState(initial.popup_enabled);
  const [startAt, setStartAt] = useState(isoToLocalInput(initial.popup_start_at));
  const [title, setTitle] = useState(initial.popup_title ?? "");
  const [body, setBody] = useState(initial.popup_body ?? "");
  const [imageUrl, setImageUrl] = useState(initial.popup_image_url ?? "");

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    const result = await savePopupConfig({
      popup_enabled: enabled,
      popup_start_at: localInputToIso(startAt),
      popup_title: title || null,
      popup_body: body || null,
      popup_image_url: imageUrl || null,
    });
    setBusy(false);
    if (!result.ok) return toast.error(result.error);
    toast.success("Pop-up settings saved");
    router.refresh();
  }

  return (
    <Card className="max-w-2xl">
      <CardHeader>
        <CardTitle>Next-event pop-up</CardTitle>
        <CardDescription>
          Shown to attendees from the start time below. They can close it while
          their access is active; after access ends it becomes the home screen.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <form onSubmit={onSubmit} className="space-y-5">
          <div className="flex items-center gap-2">
            <input
              id="enabled"
              type="checkbox"
              checked={enabled}
              onChange={(e) => setEnabled(e.target.checked)}
              className="h-4 w-4 accent-primary"
            />
            <Label htmlFor="enabled">Enable pop-up</Label>
          </div>

          <div className="space-y-2">
            <Label htmlFor="startAt">Show from</Label>
            <Input
              id="startAt"
              type="datetime-local"
              value={startAt}
              onChange={(e) => setStartAt(e.target.value)}
            />
            <p className="text-xs text-muted-foreground">
              Leave blank to show immediately. Set this to day 6 of the retreat.
            </p>
          </div>

          <div className="space-y-2">
            <Label htmlFor="title">Title</Label>
            <Input
              id="title"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="Our Next Retreat"
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="body">Details</Label>
            <Textarea
              id="body"
              rows={4}
              value={body}
              onChange={(e) => setBody(e.target.value)}
              placeholder="Dates, location, and how to register…"
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="imageUrl">Image URL (optional)</Label>
            <Input
              id="imageUrl"
              value={imageUrl}
              onChange={(e) => setImageUrl(e.target.value)}
              placeholder="https://…"
            />
          </div>

          <Button type="submit" disabled={busy}>
            {busy ? "Saving…" : "Save settings"}
          </Button>
        </form>
      </CardContent>
    </Card>
  );
}
