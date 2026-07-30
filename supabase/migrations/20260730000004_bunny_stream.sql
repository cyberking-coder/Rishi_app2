-- Video delivery via Bunny Stream.
--
-- Audio stays on R2 exactly as it is. Video moves to Bunny because it
-- needs transcoding into a quality ladder, which R2 (plain object
-- storage) can't do — a single high-bitrate MP4 stalls on mobile data.
--
-- Bunny keeps its own copy and serves it from its own CDN, so a Bunny
-- video has no r2_path. `bunny_video_id` being non-null is what marks a
-- video as Bunny-backed; anything without it still plays from R2 through
-- the original path, so existing content is unaffected.
alter table public.videos
  add column if not exists bunny_video_id text,
  -- Transcoding is asynchronous: Bunny accepts the file, then takes a
  -- while to encode it. A video isn't playable until this reaches
  -- 'ready', so the admin UI can show progress instead of offering a
  -- lesson that would fail.
  add column if not exists bunny_status text
    check (bunny_status is null or bunny_status in ('uploading', 'processing', 'ready', 'failed'));

create index if not exists idx_videos_bunny on public.videos (bunny_video_id)
  where bunny_video_id is not null;
