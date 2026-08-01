"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Upload } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  removeCertificateTemplate,
  updateCertificateLayout,
  uploadCertificateTemplate,
} from "@/app/actions/courses";
import type { Course } from "@/lib/types";

/**
 * A soft contrasting outline behind the name.
 *
 * Certificate artwork is often busy — a starfield, a photograph, a
 * gradient — and a name with no separation from it becomes unreadable
 * exactly where the design is most detailed. Derived from the chosen
 * colour rather than configured: dark text gets a light halo and light
 * text a dark one, so it helps on any artwork without another setting to
 * get wrong. Kept in step with _halo() in the app's certificate screen.
 */
function haloFor(hex: string, sizeCqw: number): string {
  const clean = hex.replace("#", "");
  const rgb =
    clean.length === 6
      ? [0, 2, 4].map((i) => parseInt(clean.slice(i, i + 2), 16))
      : [26, 26, 26];
  const luma = (0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2]) / 255;
  const halo = luma > 0.6 ? "rgba(0,0,0,0.6)" : "rgba(255,255,255,0.7)";
  const blur = sizeCqw * 0.09;
  return `0 0 ${blur}cqw ${halo}, 0 0 ${blur * 2}cqw ${halo}`;
}

function fileToBase64(f: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve((reader.result as string).split(",")[1] ?? "");
    reader.onerror = () => reject(new Error("Could not read file"));
    reader.readAsDataURL(f);
  });
}

/**
 * Upload your own certificate artwork and place the recipient's name on
 * it.
 *
 * The preview is the whole point of this component. Position is stored
 * as percentages so one template renders correctly at any size, but
 * percentages are impossible to guess against a specific design — so the
 * preview shows a sample name on the real artwork at the real relative
 * position, and moving a slider moves it live.
 */
export function CertificateTemplateEditor({ course }: { course: Course }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);

  const [top, setTop] = useState(Number(course.certificate_name_top ?? 52));
  const [left, setLeft] = useState(Number(course.certificate_name_left ?? 50));
  const [size, setSize] = useState(Number(course.certificate_name_size ?? 7));
  const [color, setColor] = useState(
    course.certificate_name_color ?? "#1A1A1A",
  );
  const [sampleName, setSampleName] = useState("Ritesh Kelkar");

  const templateUrl = course.certificate_template_url;

  async function upload(file: File) {
    setBusy(true);
    try {
      const result = await uploadCertificateTemplate({
        courseId: course.id,
        fileName: file.name,
        contentType: file.type || "image/png",
        base64: await fileToBase64(file),
      });
      if (!result.ok) return toast.error(result.error);
      toast.success("Template uploaded.");
      router.refresh();
    } finally {
      setBusy(false);
    }
  }

  async function saveLayout() {
    setBusy(true);
    try {
      const result = await updateCertificateLayout({
        courseId: course.id,
        top,
        left,
        size,
        color,
      });
      if (!result.ok) return toast.error(result.error);
      toast.success("Name position saved.");
      router.refresh();
    } finally {
      setBusy(false);
    }
  }

  async function remove() {
    if (
      !window.confirm(
        "Remove this template? Certificates for this course will go back " +
          "to the app's own design.",
      )
    ) {
      return;
    }
    setBusy(true);
    try {
      const result = await removeCertificateTemplate(course.id);
      if (!result.ok) return toast.error(result.error);
      toast.success("Template removed.");
      router.refresh();
    } finally {
      setBusy(false);
    }
  }

  return (
    <Card className="mt-6">
      <CardHeader>
        <CardTitle>Certificate design</CardTitle>
      </CardHeader>
      <CardContent className="space-y-5">
        <p className="text-sm text-muted-foreground">
          Upload your own certificate artwork with the name area left blank.
          The learner&apos;s name is printed onto it once they finish every
          lesson in this course. Leave this empty and the app draws its own
          certificate instead.
        </p>

        <div className="flex flex-wrap items-center gap-2">
          <Button asChild variant="outline" size="sm" disabled={busy}>
            <label className="cursor-pointer">
              <Upload className="mr-1.5 h-3.5 w-3.5" />
              {templateUrl ? "Replace artwork" : "Upload artwork"}
              <input
                type="file"
                accept="image/png,image/jpeg,image/webp"
                className="hidden"
                onChange={(e) => {
                  const file = e.target.files?.[0];
                  if (file) void upload(file);
                  e.target.value = "";
                }}
              />
            </label>
          </Button>
          {templateUrl && (
            <Button
              variant="ghost"
              size="sm"
              disabled={busy}
              onClick={remove}
              className="text-destructive hover:text-destructive"
            >
              Remove
            </Button>
          )}
        </div>

        {!templateUrl ? (
          <div className="rounded-lg border border-dashed p-8 text-center text-sm text-muted-foreground">
            No artwork uploaded. Landscape works best — around 1600×1130 px,
            PNG or JPG.
          </div>
        ) : (
          <>
            {/* The preview mirrors exactly what the app renders: the
                artwork at its natural aspect ratio, with the name
                positioned by percentage on top. Anything that looks
                right here looks right on the phone. */}
            <div
              className="relative w-full overflow-hidden rounded-lg border"
              // Container query units below are relative to THIS element's
              // width, which is the artwork's width — the same basis the
              // app sizes against. Without it, cqw would resolve against
              // some ancestor and the preview would lie.
              style={{ containerType: "inline-size" }}
            >
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={templateUrl}
                alt="Certificate template"
                className="block w-full"
              />
              <div
                className="pointer-events-none absolute -translate-x-1/2 -translate-y-1/2 text-center font-semibold leading-tight"
                style={{
                  top: `${top}%`,
                  left: `${left}%`,
                  color,
                  fontSize: `${size}cqw`,
                  // Mirrors the halo the app draws, derived from the
                  // chosen colour the same way — the preview has to show
                  // the readability aid, not a cleaner version of it.
                  textShadow: haloFor(color, size),
                  // Kept off the artwork's edges, and the same bound the
                  // app applies — a name that wraps here wraps there.
                  maxWidth: "84cqw",
                }}
              >
                {sampleName || "Recipient name"}
              </div>
            </div>

            <div className="grid gap-4 sm:grid-cols-2">
              <div className="space-y-1.5">
                <Label htmlFor="sample">Preview name</Label>
                <Input
                  id="sample"
                  value={sampleName}
                  onChange={(e) => setSampleName(e.target.value)}
                  placeholder="A long name, to check it fits"
                />
                <p className="text-xs text-muted-foreground">
                  Try your longest expected name — it wraps rather than
                  overflowing, but a wrap may collide with the artwork.
                </p>
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="color">Name colour</Label>
                <div className="flex items-center gap-2">
                  <input
                    id="color"
                    type="color"
                    value={color}
                    onChange={(e) => setColor(e.target.value)}
                    className="h-9 w-14 cursor-pointer rounded border bg-transparent"
                  />
                  <Input
                    value={color}
                    onChange={(e) => setColor(e.target.value)}
                    className="font-mono"
                  />
                </div>
              </div>
            </div>

            <Slider
              label="Vertical position"
              value={top}
              min={0}
              max={100}
              step={0.5}
              suffix="% from top"
              onChange={setTop}
            />
            <Slider
              label="Horizontal centre"
              value={left}
              min={0}
              max={100}
              step={0.5}
              suffix="% from left"
              onChange={setLeft}
            />
            <Slider
              label="Name size"
              value={size}
              min={1}
              max={20}
              step={0.1}
              suffix="% of width"
              onChange={setSize}
            />

            <Button disabled={busy} onClick={saveLayout}>
              {busy ? "Saving…" : "Save name position"}
            </Button>
          </>
        )}
      </CardContent>
    </Card>
  );
}

function Slider({
  label,
  value,
  min,
  max,
  step,
  suffix,
  onChange,
}: {
  label: string;
  value: number;
  min: number;
  max: number;
  step: number;
  suffix: string;
  onChange: (v: number) => void;
}) {
  return (
    <div className="space-y-1.5">
      <div className="flex items-center justify-between">
        <Label>{label}</Label>
        <span className="text-xs text-muted-foreground">
          {value}
          {suffix ? ` ${suffix}` : ""}
        </span>
      </div>
      <input
        type="range"
        min={min}
        max={max}
        step={step}
        value={value}
        onChange={(e) => onChange(Number(e.target.value))}
        className="w-full accent-primary"
      />
    </div>
  );
}
