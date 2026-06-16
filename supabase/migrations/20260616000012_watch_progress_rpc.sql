-- watch_history's uniqueness is enforced via partial indexes
-- (uq_watch_history_user_video / uq_watch_history_user_audio), which a
-- plain PostgREST upsert's ON CONFLICT clause cannot target. This RPC
-- does the update-or-insert explicitly instead.
create or replace function public.upsert_watch_progress(
  p_video_id uuid,
  p_audio_id uuid,
  p_progress_seconds int,
  p_duration_seconds int,
  p_completed boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if num_nonnulls(p_video_id, p_audio_id) <> 1 then
    raise exception 'Exactly one of p_video_id or p_audio_id must be set';
  end if;

  if p_video_id is not null then
    update public.watch_history
      set progress_seconds = p_progress_seconds,
          duration_seconds = p_duration_seconds,
          completed = p_completed,
          last_watched_at = now()
      where user_id = auth.uid() and video_id = p_video_id;
  else
    update public.watch_history
      set progress_seconds = p_progress_seconds,
          duration_seconds = p_duration_seconds,
          completed = p_completed,
          last_watched_at = now()
      where user_id = auth.uid() and audio_id = p_audio_id;
  end if;

  if not found then
    insert into public.watch_history (
      user_id, video_id, audio_id, progress_seconds, duration_seconds, completed
    )
    values (
      auth.uid(), p_video_id, p_audio_id, p_progress_seconds, p_duration_seconds, p_completed
    );
  end if;
end;
$$;
