# OTT Admin Dashboard

Next.js 14 (App Router) + TypeScript + Tailwind + Shadcn UI + Supabase
admin panel for the OTT platform.

## Features

- **Dashboard** — platform stats (users, active devices, published content, views/plays) and recent uploads.
- **Users** — list/search accounts, **create user**, change role/tier, suspend/ban, **reset device**.
- **Device Management** — every registered device with active state; reset a device so a user can re-register.
- **Videos / Audios** — list, **upload content** (direct browser→R2 presigned PUT), publish/archive, **delete content**.
- **Categories** — create/delete browse categories.
- **Analytics** — 30-day views trend (Recharts) + top videos/audios.

## Architecture

- **Auth & authorization**: cookie sessions via `@supabase/ssr`. `middleware.ts` refreshes the session and gates routes; `requireAdmin()` (server) enforces admin role on the dashboard layout and inside every privileged server action — independent of any client check.
- **RLS-respecting reads**: server components use the anon-key server client; the logged-in admin's role satisfies the existing `is_admin()` RLS policies.
- **Privileged writes**: server actions use the service-role client (`SUPABASE_SERVICE_ROLE_KEY`, server-only) *after* `requireAdmin()` — used for creating auth users, resetting another user's device, and content mutations.
- **Uploads**: server presigns a Cloudflare R2 PUT URL (`aws4fetch`); the browser uploads the file directly to R2 so bytes never transit our server. The content row is created first (draft), then marked `processing` once the object is stored.

## Setup

```bash
cd admin
cp .env.example .env       # fill in Supabase + R2 values
npm install
npm run dev
```

The signed-in account must have a `profiles.role` of `admin`,
`content_manager`, or `support`.

## Env

See `.env.example`. `SUPABASE_SERVICE_ROLE_KEY` and all `R2_*` values are
server-only — never exposed to the browser.
