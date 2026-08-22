"use client";

import { useState } from "react";
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
import { grantCourseAccess } from "@/app/actions/courses";

/**
 * Lets somebody into this course without a payment.
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
              required
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
              disabled={busy}
            >
              Cancel
            </Button>
            <Button type="submit" disabled={busy}>
              {busy ? "Granting…" : "Grant access"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
