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

/** Splits a stored ISO timestamp into local date (YYYY-MM-DD) and time
 *  (HH:mm) strings for the two inputs, and recombines them. */
function isoToDate(iso: string | null): string {
  if (!iso) return "";
  const d = new Date(iso);
  const off = d.getTimezoneOffset() * 60000;
  return new Date(d.getTime() - off).toISOString().slice(0, 10);
}

function isoToTime(iso: string | null): string {
  if (!iso) return "";
  const d = new Date(iso);
  const off = d.getTimezoneOffset() * 60000;
  return new Date(d.getTime() - off).toISOString().slice(11, 16);
}

function dateTimeToIso(date: string, time: string): string | null {
  if (!date) return null;
  // Default to midnight if only a date was chosen.
  const t = time || "00:00";
  return new Date(`${date}T${t}`).toISOString();
}

export function PopupConfigForm({ initial }: { initial: PopupConfig }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);

  const [enabled, setEnabled] = useState(initial.popup_enabled);
  const [startDate, setStartDate] = useState(isoToDate(initial.popup_start_at));
  const [startTime, setStartTime] = useState(isoToTime(initial.popup_start_at));
  const [title, setTitle] = useState(initial.popup_title ?? "");
  const [body, setBody] = useState(initial.popup_body ?? "");
  const [imageUrl, setImageUrl] = useState(initial.popup_image_url ?? "");

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    const result = await savePopupConfig({
      popup_enabled: enabled,
      popup_start_at: dateTimeToIso(startDate, startTime),
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
            <Label>Show from</Label>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1">
                <Label htmlFor="startDate" className="text-xs text-muted-foreground">
                  Date
                </Label>
                <Input
                  id="startDate"
                  type="date"
                  value={startDate}
                  onChange={(e) => setStartDate(e.target.value)}
                />
              </div>
              <div className="space-y-1">
                <Label htmlFor="startTime" className="text-xs text-muted-foreground">
                  Time
                </Label>
                <Input
                  id="startTime"
                  type="time"
                  value={startTime}
                  onChange={(e) => setStartTime(e.target.value)}
                />
              </div>
            </div>
            <p className="text-xs text-muted-foreground">
              Leave the date blank to show immediately. Set this to day 6 of
              the retreat.
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
