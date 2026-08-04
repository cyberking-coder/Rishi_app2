"use client";

import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { CalendarDays, Clock, ImagePlus, Plus, Trash2, X } from "lucide-react";
import {
  deletePopup,
  savePopup,
  uploadPopupImage,
  type AppPopup,
} from "@/app/actions/config";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { NativeSelect, NativeOption } from "@/components/ui/native-select";
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

/** ISO-8601 weekday numbers, which is what the app compares against. */
const WEEKDAYS = [
  { value: "", label: "Every day" },
  { value: "1", label: "Monday" },
  { value: "2", label: "Tuesday" },
  { value: "3", label: "Wednesday" },
  { value: "4", label: "Thursday" },
  { value: "5", label: "Friday" },
  { value: "6", label: "Saturday" },
  { value: "7", label: "Sunday" },
];

export function PopupConfigForm({ initial }: { initial: AppPopup[] }) {
  const router = useRouter();

  // Drafts for pop-ups that have not been saved yet. Held separately from
  // the server list so an unsaved card is never confused for a stored row
  // — the two need different save calls and different image paths.
  const [drafts, setDrafts] = useState<number[]>(
    initial.length === 0 ? [0] : [],
  );

  return (
    <div className="max-w-2xl space-y-5">
      <Card>
        <CardHeader>
          <CardTitle>In-app pop-ups</CardTitle>
          <CardDescription>
            Each pop-up can run every day or on one day of the week — a
            Monday message and a Wednesday message, for instance. Days are
            read in IST, and each pop-up is shown once per day per person
            rather than on every launch.
            <br />
            <br />
            If two pop-ups match the same day, the one higher up this list
            wins. Only that one is shown.
          </CardDescription>
        </CardHeader>
      </Card>

      {initial.map((popup, index) => (
        <PopupCard
          key={popup.id}
          popup={popup}
          position={index + 1}
          onDone={() => router.refresh()}
        />
      ))}

      {drafts.map((key) => (
        <PopupCard
          key={`draft-${key}`}
          popup={null}
          position={initial.length + drafts.indexOf(key) + 1}
          onDone={() => {
            setDrafts((d) => d.filter((k) => k !== key));
            router.refresh();
          }}
        />
      ))}

      <Button
        type="button"
        variant="outline"
        onClick={() => setDrafts((d) => [...d, Date.now()])}
      >
        <Plus className="mr-2 h-4 w-4" />
        Add a pop-up
      </Button>
    </div>
  );
}

function PopupCard({
  popup,
  position,
  onDone,
}: {
  popup: AppPopup | null;
  position: number;
  onDone: () => void;
}) {
  const [busy, setBusy] = useState(false);

  const [enabled, setEnabled] = useState(popup?.enabled ?? true);
  const [weekday, setWeekday] = useState(
    popup?.weekday == null ? "" : String(popup.weekday),
  );
  const [startDate, setStartDate] = useState(isoToDate(popup?.starts_at ?? null));
  const [startTime, setStartTime] = useState(isoToTime(popup?.starts_at ?? null));
  const [title, setTitle] = useState(popup?.title ?? "");
  const [body, setBody] = useState(popup?.body ?? "");
  const [imageUrl, setImageUrl] = useState(popup?.image_url ?? "");
  const [imageUploading, setImageUploading] = useState(false);

  const dateRef = useRef<HTMLInputElement>(null);
  const timeRef = useRef<HTMLInputElement>(null);
  const imageInputRef = useRef<HTMLInputElement>(null);

  // An unsaved pop-up has no id yet, so its image needs some other stable
  // name. Generated once per card so re-picking a file overwrites the
  // previous attempt instead of littering the bucket.
  const uploadKeyRef = useRef(
    popup?.id ?? `draft-${Math.random().toString(36).slice(2, 10)}`,
  );

  function openPicker(ref: React.RefObject<HTMLInputElement | null>) {
    // showPicker() reliably opens the native calendar/clock on click.
    try {
      ref.current?.showPicker();
    } catch {
      ref.current?.focus();
    }
  }

  async function handleImageFile(file: File) {
    setImageUploading(true);
    const ext = file.name.split(".").pop() ?? "jpg";
    const base64 = await new Promise<string>((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve((reader.result as string).split(",")[1]);
      reader.onerror = reject;
      reader.readAsDataURL(file);
    });
    const result = await uploadPopupImage(
      base64,
      file.type,
      ext,
      uploadKeyRef.current,
    );
    setImageUploading(false);
    if (!result.ok) return toast.error(result.error);
    setImageUrl(result.url);
  }

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();

    if (!title.trim() && !body.trim()) {
      return toast.error("Give the pop-up a title or some text to show.");
    }

    setBusy(true);
    const result = await savePopup({
      id: popup?.id,
      title: title || null,
      body: body || null,
      image_url: imageUrl || null,
      weekday: weekday === "" ? null : Number(weekday),
      starts_at: dateTimeToIso(startDate, startTime),
      enabled,
      sort_order: position - 1,
    });
    setBusy(false);
    if (!result.ok) return toast.error(result.error);
    toast.success("Pop-up saved");
    onDone();
  }

  async function onDelete() {
    if (!popup) return onDone();
    if (!confirm("Delete this pop-up? This cannot be undone.")) return;

    setBusy(true);
    const result = await deletePopup(popup.id);
    setBusy(false);
    if (!result.ok) return toast.error(result.error);
    toast.success("Pop-up deleted");
    onDone();
  }

  const dayLabel =
    WEEKDAYS.find((d) => d.value === weekday)?.label ?? "Every day";

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center justify-between text-base">
          <span>
            {position}. {title.trim() || "Untitled pop-up"}
          </span>
          <span className="text-sm font-normal text-muted-foreground">
            {enabled ? dayLabel : "Off"}
          </span>
        </CardTitle>
      </CardHeader>
      <CardContent>
        <form onSubmit={onSubmit} className="space-y-5">
          <div className="flex items-center gap-2">
            <input
              id={`enabled-${uploadKeyRef.current}`}
              type="checkbox"
              checked={enabled}
              onChange={(e) => setEnabled(e.target.checked)}
              className="h-4 w-4 accent-primary"
            />
            <Label htmlFor={`enabled-${uploadKeyRef.current}`}>
              Enable pop-up
            </Label>
          </div>

          <div className="space-y-2">
            <Label htmlFor={`weekday-${uploadKeyRef.current}`}>Show on</Label>
            <NativeSelect
              id={`weekday-${uploadKeyRef.current}`}
              value={weekday}
              onChange={(e) => setWeekday(e.target.value)}
            >
              {WEEKDAYS.map((d) => (
                <NativeOption key={d.value} value={d.value}>
                  {d.label}
                </NativeOption>
              ))}
            </NativeSelect>
            <p className="text-xs text-muted-foreground">
              Repeats weekly. The day is read in IST, so it matches the day
              you would call it here regardless of where the user is.
            </p>
          </div>

          <div className="space-y-2">
            <Label>Not before</Label>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1">
                <Label className="text-xs text-muted-foreground">Date</Label>
                <div className="relative">
                  <Input
                    ref={dateRef}
                    type="date"
                    value={startDate}
                    onChange={(e) => setStartDate(e.target.value)}
                    className="pr-10 [&::-webkit-calendar-picker-indicator]:opacity-0"
                  />
                  <button
                    type="button"
                    onClick={() => openPicker(dateRef)}
                    className="absolute inset-y-0 right-0 flex w-10 items-center justify-center text-muted-foreground hover:text-foreground"
                    aria-label="Open calendar"
                  >
                    <CalendarDays className="h-4 w-4" />
                  </button>
                </div>
              </div>
              <div className="space-y-1">
                <Label className="text-xs text-muted-foreground">Time</Label>
                <div className="relative">
                  <Input
                    ref={timeRef}
                    type="time"
                    value={startTime}
                    onChange={(e) => setStartTime(e.target.value)}
                    className="pr-10 [&::-webkit-calendar-picker-indicator]:opacity-0"
                  />
                  <button
                    type="button"
                    onClick={() => openPicker(timeRef)}
                    className="absolute inset-y-0 right-0 flex w-10 items-center justify-center text-muted-foreground hover:text-foreground"
                    aria-label="Open time picker"
                  >
                    <Clock className="h-4 w-4" />
                  </button>
                </div>
              </div>
            </div>
            <p className="text-xs text-muted-foreground">
              Leave blank to start straight away. Use it to write a message
              now that should only begin appearing later.
            </p>
          </div>

          <div className="space-y-2">
            <Label>Title</Label>
            <Input
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="Our Next Retreat"
            />
          </div>

          <div className="space-y-2">
            <Label>Details</Label>
            <Textarea
              rows={4}
              value={body}
              onChange={(e) => setBody(e.target.value)}
              placeholder="Dates, location, and how to register…"
            />
          </div>

          <div className="space-y-2">
            <Label>Pop-up image (optional)</Label>
            <input
              ref={imageInputRef}
              type="file"
              accept="image/*"
              className="hidden"
              onChange={(e) => {
                const file = e.target.files?.[0];
                if (file) handleImageFile(file);
                e.target.value = "";
              }}
            />
            {imageUrl ? (
              <div className="relative inline-block">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={imageUrl}
                  alt="Pop-up preview"
                  className="h-32 w-auto rounded-md border object-cover"
                />
                <button
                  type="button"
                  onClick={() => setImageUrl("")}
                  className="absolute -right-2 -top-2 flex h-5 w-5 items-center justify-center rounded-full bg-destructive text-destructive-foreground"
                  aria-label="Remove image"
                >
                  <X className="h-3 w-3" />
                </button>
              </div>
            ) : null}
            <div>
              <Button
                type="button"
                variant="outline"
                size="sm"
                disabled={imageUploading}
                onClick={() => imageInputRef.current?.click()}
              >
                <ImagePlus className="mr-2 h-4 w-4" />
                {imageUploading
                  ? "Uploading…"
                  : imageUrl
                    ? "Change image"
                    : "Choose file"}
              </Button>
            </div>
          </div>

          <div className="flex items-center gap-3">
            <Button type="submit" disabled={busy}>
              {busy ? "Saving…" : popup ? "Save changes" : "Create pop-up"}
            </Button>
            <Button
              type="button"
              variant="ghost"
              size="sm"
              disabled={busy}
              onClick={onDelete}
              className="text-destructive hover:text-destructive"
            >
              <Trash2 className="mr-2 h-4 w-4" />
              {popup ? "Delete" : "Discard"}
            </Button>
          </div>
        </form>
      </CardContent>
    </Card>
  );
}
