"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import {
  createLiveSession,
  updateLiveSession,
  uploadSessionThumbnail,
} from "@/app/actions/sessions";
import type { LiveSession } from "@/lib/types";

/// Both directions between the `datetime-local` input and the UTC the
/// database stores, fixed to IST.
///
/// Pinned rather than using the browser's own zone, because the table
/// that lists these renders on the server (which is UTC) — so a
/// browser-local form and a server-rendered list disagreed by five and a
/// half hours, and neither told you which one to believe. One stated
/// zone on both sides is the only version of this that can't drift.
///
/// A fixed +05:30 offset is exact: India has no daylight saving, so
/// there is no date on which this is wrong, and no zone library needed.
const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;

function istInputToIso(local: string): string {
  return new Date(`${local}:00+05:30`).toISOString();
}

function isoToIstInput(iso: string): string {
  return new Date(new Date(iso).getTime() + IST_OFFSET_MS)
    .toISOString()
    .slice(0, 16);
}

/// One dialog for both add and edit — the fields are identical, and two
/// copies would drift the moment either changed.
export function SessionFormDialog({
  session,
  trigger,
}: {
  session?: LiveSession;
  trigger?: React.ReactNode;
}) {
  const router = useRouter();
  const editing = Boolean(session);

  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);

  const [title, setTitle] = useState(session?.title ?? "");
  const [description, setDescription] = useState(session?.description ?? "");
  const [joinUrl, setJoinUrl] = useState(session?.join_url ?? "");
  const [startsAt, setStartsAt] = useState(
    session ? isoToIstInput(session.starts_at) : "",
  );
  const [duration, setDuration] = useState(
    String(session?.duration_minutes ?? 60),
  );
  const [thumbnailUrl, setThumbnailUrl] = useState(
    session?.thumbnail_url ?? "",
  );
  const [uploading, setUploading] = useState(false);

  // Entered in rupees, stored in paise. Kept as a string while typing so
  // the box can be cleared — a number state snaps an empty field back to
  // 0 on every keystroke.
  const [priceRupees, setPriceRupees] = useState(
    session?.price_amount ? String(session.price_amount / 100) : "",
  );
  const [seatLimit, setSeatLimit] = useState(
    session?.seat_limit == null ? "" : String(session.seat_limit),
  );

  function reset() {
    if (editing) return;
    setTitle("");
    setDescription("");
    setJoinUrl("");
    setStartsAt("");
    setDuration("60");
    setThumbnailUrl("");
    setPriceRupees("");
    setSeatLimit("");
  }

  async function onPickThumbnail(file: File) {
    setUploading(true);
    try {
      const base64 = Buffer.from(await file.arrayBuffer()).toString("base64");
      const result = await uploadSessionThumbnail({
        fileName: file.name,
        contentType: file.type || "image/jpeg",
        base64,
      });
      if (!result.ok) throw new Error(result.error);
      setThumbnailUrl(result.url);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Upload failed");
    } finally {
      setUploading(false);
    }
  }

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();

    const rupees = priceRupees.trim() === "" ? 0 : Number(priceRupees);
    if (Number.isNaN(rupees) || rupees < 0) {
      return toast.error("Enter a valid fee, or leave it blank for free.");
    }
    const seats = seatLimit.trim() === "" ? null : Number(seatLimit);
    if (seats !== null && (!Number.isInteger(seats) || seats < 1)) {
      return toast.error("Seats must be a whole number, or blank for no limit.");
    }

    setBusy(true);
    try {
      const payload = {
        title,
        description: description || undefined,
        joinUrl,
        // Read as IST and converted once, here, so nothing downstream
        // has to guess a zone.
        startsAt: istInputToIso(startsAt),
        durationMinutes: Number(duration),
        thumbnailUrl: thumbnailUrl || undefined,
        // Rounded here rather than left to the database: 499.995 has to
        // land on a whole paisa before it becomes an amount somebody is
        // charged.
        priceAmount: rupees > 0 ? Math.round(rupees * 100) : null,
        seatLimit: seats,
      };

      const result = session
        ? await updateLiveSession({ ...payload, id: session.id })
        : await createLiveSession(payload);
      if (!result.ok) throw new Error(result.error);

      toast.success(editing ? "Session updated" : "Session scheduled");
      setOpen(false);
      reset();
      router.refresh();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Could not save");
    } finally {
      setBusy(false);
    }
  }

  return (
    <Dialog
      open={open}
      onOpenChange={(o) => {
        if (!busy) setOpen(o);
      }}
    >
      <DialogTrigger asChild>
        {trigger ?? (
          <Button>
            <Plus className="h-4 w-4" />
            Schedule session
          </Button>
        )}
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>
            {editing ? "Edit session" : "Schedule a live session"}
          </DialogTitle>
          <DialogDescription>
            Shown in the app&apos;s Watch section. Everyone with the app gets a
            notification an hour, 30 minutes and 5 minutes before it starts.
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={onSubmit} className="space-y-4">
          <div>
            <Label htmlFor="ls-title">Title</Label>
            <Input
              id="ls-title"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="Sunday morning satsang"
              disabled={busy}
            />
          </div>

          <div className="space-y-3 rounded-md border p-4">
            <div>
              <Label>Paid session (optional)</Label>
              <p className="pt-1 text-xs text-muted-foreground">
                Set a fee and members see &ldquo;Register &bull;
                &nbsp;₹499&rdquo; instead of a join button. They pay, get a
                WhatsApp confirmation, and only then can open the meeting
                link. Leave it blank and the session is free to join, as
                every existing session is.
              </p>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <Label htmlFor="ls-price" className="text-xs text-muted-foreground">
                  Fee (₹)
                </Label>
                <Input
                  id="ls-price"
                  type="number"
                  min={0}
                  step="1"
                  inputMode="decimal"
                  value={priceRupees}
                  onChange={(e) => setPriceRupees(e.target.value)}
                  placeholder="499"
                  disabled={busy}
                />
              </div>
              <div>
                <Label htmlFor="ls-seats" className="text-xs text-muted-foreground">
                  Seats (blank = no limit)
                </Label>
                <Input
                  id="ls-seats"
                  type="number"
                  min={1}
                  step="1"
                  value={seatLimit}
                  onChange={(e) => setSeatLimit(e.target.value)}
                  placeholder="50"
                  disabled={busy}
                />
              </div>
            </div>
            <p className="text-xs text-muted-foreground">
              The meeting link of a paid session is hidden from anyone who
              has not paid — it is not stored on the row members can read.
            </p>
          </div>

          <div>
            <Label htmlFor="ls-url">Meeting link</Label>
            <Input
              id="ls-url"
              value={joinUrl}
              onChange={(e) => setJoinUrl(e.target.value)}
              placeholder="https://zoom.us/j/…"
              disabled={busy}
            />
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <Label htmlFor="ls-start">Starts (IST)</Label>
              <Input
                id="ls-start"
                type="datetime-local"
                value={startsAt}
                onChange={(e) => setStartsAt(e.target.value)}
                disabled={busy}
              />
            </div>
            <div>
              <Label htmlFor="ls-duration">Duration (minutes)</Label>
              <Input
                id="ls-duration"
                type="number"
                min={1}
                value={duration}
                onChange={(e) => setDuration(e.target.value)}
                disabled={busy}
              />
            </div>
          </div>

          <div>
            <Label htmlFor="ls-desc">Description</Label>
            <Textarea
              id="ls-desc"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              rows={2}
              disabled={busy}
            />
          </div>

          <div>
            <Label htmlFor="ls-thumb">Thumbnail</Label>
            <Input
              id="ls-thumb"
              type="file"
              accept="image/*"
              disabled={busy || uploading}
              onChange={(e) => {
                const file = e.target.files?.[0];
                if (file) void onPickThumbnail(file);
              }}
            />
            <p className="mt-1 text-xs text-muted-foreground">
              {uploading
                ? "Uploading…"
                : thumbnailUrl
                  ? "Thumbnail set. Choose a file to replace it."
                  : "Optional. Without one the app draws a plain card."}
            </p>
          </div>

          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => setOpen(false)}
              disabled={busy}
            >
              Cancel
            </Button>
            <Button
              type="submit"
              disabled={
                busy || uploading || !title.trim() || !joinUrl.trim() || !startsAt
              }
            >
              {busy ? "Saving…" : editing ? "Save changes" : "Schedule"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
