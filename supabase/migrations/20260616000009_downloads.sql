create table public.downloads (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  device_id uuid not null references public.devices (id) on delete cascade,
  video_id uuid references public.videos (id) on delete cascade,
  audio_id uuid references public.audios (id) on delete cascade,
  license_expires_at timestamptz,
  download_status text not null default 'pending'
    check (download_status in ('pending', 'downloading', 'ready', 'expired', 'revoked')),
  encrypted_key_ref text,
  downloaded_at timestamptz,
  created_at timestamptz not null default now(),
  constraint chk_downloads_exactly_one_content
    check (num_nonnulls(video_id, audio_id) = 1)
);

create unique index uq_downloads_user_device_video
  on public.downloads (user_id, device_id, video_id)
  where (video_id is not null);

create unique index uq_downloads_user_device_audio
  on public.downloads (user_id, device_id, audio_id)
  where (audio_id is not null);

create index idx_downloads_user_id on public.downloads (user_id);
create index idx_downloads_status on public.downloads (download_status);
create index idx_downloads_license_expiry on public.downloads (license_expires_at);

-- RLS
alter table public.downloads enable row level security;

create policy "downloads_select_own_or_admin"
  on public.downloads for select
  using (user_id = auth.uid() or public.is_admin());

create policy "downloads_insert_own"
  on public.downloads for insert
  with check (
    user_id = auth.uid()
    and device_id in (
      select id from public.devices where user_id = auth.uid() and is_active
    )
  );

create policy "downloads_update_own"
  on public.downloads for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "downloads_admin_manage"
  on public.downloads for all
  using (public.is_admin())
  with check (public.is_admin());

-- Revokes all downloads tied to a device (e.g. on device-swap or
-- subscription cancellation) so the client can purge local files.
create or replace function public.revoke_downloads_for_device(p_device_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.downloads
    set download_status = 'revoked'
    where device_id = p_device_id;
$$;
