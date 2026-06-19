-- Test-mode support: a direct, public audio URL that bypasses the R2 +
-- Edge Function signing pipeline. When set, the app plays this URL
-- directly. For production content leave this null and use content_assets.
alter table public.audios add column if not exists direct_url text;
