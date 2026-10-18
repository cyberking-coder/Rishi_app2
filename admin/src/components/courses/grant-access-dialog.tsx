"use client";

import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { grantCourseAccess, grantCourseAccessBulk } from "@/app/actions/courses";

/**
 * Lets people into this course without a payment — one at a time by email,
 * or many at once by uploading a CSV of email addresses.
 *
 * Asks for an email rather than offering a list of users: the roster is
 * per-course and the whole user table is not, so a picker here would be
 * a thousand-row dropdown to find one person whose address the admin
 * already has in front of them.
 */
export function GrantAccessDialog({ courseId }: { courseId: string }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [email, setEmail] = useState("");

  // Bulk CSV
  const fileRef = useRef<HTMLInputElement>(null);
  const [bulkBusy, setBulkBusy] = useState(false);
  const [notFound, setNotFound] = useState<string[]>([]);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    try {
      const result = await grantCourseAccess(email, courseId);
      if (!result.ok) return toast.error(result.error);
      toast.success(`${email.trim()} now has access to this course.`);
      setEmail("");
      setOpen(false);
      router.refresh();
    } finally {
      setBusy(false);
    }
  }

  async function submitBulk() {
    const file = fileRef.current?.files?.[0];
    if (!file) return toast.error("Choose a CSV file first.");
    setBulkBusy(true);
    setNotFound([]);
    try {
      const text = await file.text();
      const result = await grantCourseAccessBulk(text, courseId);
      if (!result.ok) return toast.error(result.error);

      const parts = [`${result.granted} granted`];
      if (result.alreadyHad > 0) parts.push(`${result.alreadyHad} already had access`);
      if (result.notFound.length > 0) parts.push(`${result.notFound.length} without an account`);
      toast.success(`${result.total} emails: ${parts.join(", ")}.`);
      setNotFound(result.notFound);
      if (fileRef.current) fileRef.current.value = "";
      router.refresh();
    } finally {
      setBulkBusy(false);
    }
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button variant="outline" size="sm">
          Grant access
        </Button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Grant access to this course</DialogTitle>
        </DialogHeader>

        <form onSubmit={submit} className="space-y-4">
          <div className="space-y-1.5">
            <Label htmlFor="grant-email">Account email</Label>
            <Input
              id="grant-email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="person@example.com"
              autoComplete="off"
            />
            <p className="text-xs text-muted-foreground">
              The person must already have an account — access is granted to an
              account, not to an address. They appear on the roster below with
              ₹0 recorded, since nothing was charged, and the course unlocks in
              the app the next time it loads.
            </p>
          </div>

          <DialogFooter>
            <Button
              type="button"
              variant="ghost"
              onClick={() => setOpen(false)}
              disabled={busy || bulkBusy}
            >
              Cancel
            </Button>
            <Button type="submit" disabled={busy || bulkBusy || !email.trim()}>
              {busy ? "Granting…" : "Grant access"}
            </Button>
          </DialogFooter>
        </form>

        {/* ── Bulk upload ─────────────────────────────────────────────── */}
        <div className="mt-2 border-t pt-4 space-y-2">
          <Label htmlFor="grant-csv">Grant to many (CSV)</Label>
          <p className="text-xs text-muted-foreground">
            Upload a CSV containing the users&apos; email addresses (a plain
            list, or a column of emails — other columns and a header row are
            ignored). Everyone with an account is enrolled at once; addresses
            with no account are skipped and listed below.
          </p>
          <div className="flex items-center gap-2">
            <Input
              id="grant-csv"
              ref={fileRef}
              type="file"
              accept=".csv,text/csv,text/plain"
              disabled={bulkBusy || busy}
              className="text-sm"
            />
            <Button
              type="button"
              variant="secondary"
              onClick={submitBulk}
              disabled={bulkBusy || busy}
            >
              {bulkBusy ? "Granting…" : "Grant to all"}
            </Button>
          </div>

          {notFound.length > 0 && (
            <div className="rounded-md border border-amber-300 bg-amber-50 p-2 text-xs text-amber-900">
              <p className="font-medium">
                {notFound.length} address{notFound.length === 1 ? "" : "es"} had
                no account and were skipped:
              </p>
              <p className="mt-1 break-words">{notFound.join(", ")}</p>
            </div>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
}
