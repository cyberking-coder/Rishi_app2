-- Let an uploaded audio file be an M4A.
--
-- Nothing in this stack transcodes audio: attachUpload registers the
-- uploaded file as the playable asset and the app streams those exact
-- bytes. So the container an admin exports is the container a listener's
-- phone has to seek around inside.
--
-- MP3 is the bad one. It carries no index, so a variable-bitrate MP3
-- without a Xing/Info header gives a player nothing to map a timestamp
-- onto a byte offset with. Android's ExoPlayer has a constant-bitrate
-- fallback that hides this; AVPlayer on iOS does not, which is why the
-- same file scrubs cleanly on Android and badly on an iPhone. An MP4
-- container carries a sample table, so M4A/AAC seeks exactly on both.
--
-- Until now 'audio_m4a' was not in this constraint, so an admin who did
-- the right thing and exported M4A would have had it stored — and later
-- served — mislabelled as 'audio_mp3'. This adds the value; the app
-- reads content_assets.r2_path and never parses the label, so existing
-- rows are unaffected and nothing needs backfilling.

alter table public.content_assets
  drop constraint if exists content_assets_asset_type_check;

alter table public.content_assets
  add constraint content_assets_asset_type_check check (asset_type in (
    'video_hls', 'video_mp4', 'audio_hls', 'audio_mp3', 'audio_m4a',
    'poster', 'thumbnail', 'trailer', 'subtitle'
  ));
