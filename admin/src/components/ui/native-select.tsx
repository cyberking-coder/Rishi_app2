import * as React from "react";
import { ChevronDown } from "lucide-react";
import { cn } from "@/lib/utils";

/**
 * A native <select> styled to match Input.
 *
 * Native selects render their dropdown list with the OS/browser's own
 * colours, which on a dark theme comes out white-on-white and unreadable
 * unless the options themselves carry explicit colours — so <NativeOption>
 * sets them rather than relying on inheritance.
 *
 * Preferred over the Radix Select in ui/select.tsx for plain form fields:
 * it submits with the form, works without JS, and gets native mobile
 * pickers for free.
 */
const NativeSelect = React.forwardRef<
  HTMLSelectElement,
  React.SelectHTMLAttributes<HTMLSelectElement>
>(({ className, children, ...props }, ref) => (
  <div className="relative">
    <select
      ref={ref}
      className={cn(
        "flex h-9 w-full appearance-none rounded-md border border-input bg-transparent px-3 py-1 pr-8 text-sm shadow-sm",
        "focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring",
        "disabled:cursor-not-allowed disabled:opacity-50",
        className,
      )}
      {...props}
    >
      {children}
    </select>
    <ChevronDown className="pointer-events-none absolute right-2.5 top-1/2 h-4 w-4 -translate-y-1/2 opacity-50" />
  </div>
));
NativeSelect.displayName = "NativeSelect";

const NativeOption = React.forwardRef<
  HTMLOptionElement,
  React.OptionHTMLAttributes<HTMLOptionElement>
>(({ className, ...props }, ref) => (
  <option
    ref={ref}
    // Explicit colours: the popup list is drawn by the browser and does
    // not inherit the page's theme.
    className={cn("bg-background text-foreground", className)}
    {...props}
  />
));
NativeOption.displayName = "NativeOption";

export { NativeSelect, NativeOption };
