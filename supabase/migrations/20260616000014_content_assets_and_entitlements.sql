-- Content assets + entitlements.
--
-- These two tables are required by the playback edge functions
-- (issue-playback-license / issue-audio-license):
--   * content_assets  — the registry of playable files in R2. One source
--     row per uploaded master, plus one row per transcoded rendition.
--     This is the ONLY place that maps a piece of content to an R2 object
--     key, so signed-URL issuance has a single source of truth.
--   * entitlements    — who may play premium content, and until when.

-- ---------------------------------------------------------------------------
-- content_assets
-- ---------------------------------------------------------------------------
create table public.content_assets (
  id uuid primary key default gen_random_uuid(),
  -- Polymorphic parent: a videos.id or an audios.id. No FK because it can
  -- reference either table; integrity is enforced by the admin upload API.
  content_type text not null check (content_type in ('video', 'audio')),
  content_id uuid not null,
  asset_type text not null check (asset_type in (
    'video_hls', 'video_mp4', 'audio_hls', 'audio_mp3',
    'poster', 'thumbnail', 'trailer', 'subtitle'
  )),
  -- Rendition descriptors (null for non-laddered assets like audio/poster).
  resolution text,
  bitrate int,
  -- Object key within the private R2 bucket (no bucket prefix, no leading /).
  r2_path text not null,
  bytes bigint,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'ready', 'failed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index uq_content_assets_r2_path on public.content_assets (r2_path);
create index idx_content_assets_lookup
  on public.content_assets (content_id, asset_type, status);
create index idx_content_assets_content
  on public.content_assets (content_type, content_id);

create trigger trg_content_assets_updated_at
  before update on public.content_assets
  for each row execute function public.set_updated_at();

alter table public.content_assets enable row level security;

-- Clients may read only assets that are ready to play. The r2_path is not
-- itself a secret (the bucket is private; playback still requires a signed
-- URL minted server-side), but limiting reads to 'ready' avoids leaking
-- in-progress uploads. Admins see everything.
create policy "content_assets_select_ready_or_admin"
  on public.content_assets for select
  using (status = 'ready' or public.is_admin());

create policy "content_assets_admin_manage"
  on public.content_assets for all
  using (public.is_admin())
  with check (public.is_admin());

-- ---------------------------------------------------------------------------
-- entitlements
-- ---------------------------------------------------------------------------
create table public.entitlements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  -- null content_id == all-access grant (e.g. an active subscription).
  content_id uuid,
  source text not null
    check (source in ('subscription', 'purchase', 'promo', 'admin_grant')),
  granted_at timestamptz not null default now(),
  -- The license functions filter on `expires_at > now()`, so a grant is
  -- active only while this is in the future. Use a far-future date for
  -- effectively-permanent purchases.
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

create index idx_entitlements_user on public.entitlements (user_id);
create index idx_entitlements_lookup
  on public.entitlements (user_id, content_id, expires_at);

alter table public.entitlements enable row level security;

create policy "entitlements_select_own_or_admin"
  on public.entitlements for select
  using (user_id = auth.uid() or public.is_admin());

-- Writes happen via service_role (subscription webhooks / purchase flows)
-- or by an admin; never directly from an ordinary client.
create policy "entitlements_admin_manage"
  on public.entitlements for all
  using (public.is_admin())
  with check (public.is_admin());
