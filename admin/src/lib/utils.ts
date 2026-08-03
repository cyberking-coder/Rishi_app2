import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatDate(value: string | null | undefined): string {
  if (!value) return "—";
  return new Date(value).toLocaleDateString(undefined, {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

/** Date plus time. A live session's whole meaning is the clock time, so
 *  formatDate's date-only output would drop the part that matters.
 *
 *  The zone is stated explicitly rather than left to the runtime. These
 *  pages are server components, and the server runs in UTC — so an
 *  unqualified toLocaleString rendered every session five and a half
 *  hours earlier than the admin had just typed it into the (client-side,
 *  therefore local) form. Same value, two different clocks, no way to
 *  tell which one was lying.
 *
 *  Pinned to IST because that is where the sessions are run and the
 *  admins are. Change both this and the n8n schedule together if that
 *  ever stops being true. */
export function formatDateTime(value: string | null | undefined): string {
  if (!value) return "—";
  return new Date(value).toLocaleString("en-IN", {
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
    timeZone: "Asia/Kolkata",
  });
}

export function formatNumber(value: number | null | undefined): string {
  if (value == null) return "0";
  return new Intl.NumberFormat().format(value);
}

export function slugify(input: string): string {
  return input
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}
