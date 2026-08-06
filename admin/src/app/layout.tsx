import type { Metadata, Viewport } from "next";
import "./globals.css";
import { Toaster } from "@/components/ui/sonner";

export const metadata: Metadata = {
  title: "Know Thyself Admin",
  description: "Administration dashboard for Know Thyself",
};

// Stated explicitly rather than left to the framework default. Note
// there is no maximum-scale or user-scalable=no: pinch-zoom stays
// available, and the input font size in globals.css is what stops iOS
// zooming on its own.
export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="antialiased">
        {children}
        <Toaster />
      </body>
    </html>
  );
}
