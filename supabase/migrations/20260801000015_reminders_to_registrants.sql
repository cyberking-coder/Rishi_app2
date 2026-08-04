-- Reminders for a paid session go to the people who paid, not everybody.
--
-- The fan-out has always addressed every registered device, which is
-- right for a free session — the reminder IS the invitation. For a paid
-- one it is wrong twice over: it tells people who cannot attend that
-- something starts in an hour, and it tells the people who did pay
-- nothing the others did not already know.
--
-- Free sessions are untouched and still go to everyone.
--
-- due_session_reminders() is deliberately NOT changed. The sender looks
-- the price up per reminder instead, which costs one indexed read and
-- means the resume path — which reloads a claim, not a due row — narrows
-- correctly too. Threading the price through the claim would have been
-- one more thing to keep in step for no gain.

-- ---------------------------------------------------------------------------
-- One page of a narrowed audience
-- ---------------------------------------------------------------------------
-- The join between push_tokens and workshop_registrations happens here
-- rather than in the edge function, for one practical reason: filtering
-- in PostgREST would mean fetching every registrant's id and passing
-- them back as an `in.(…)` list, which is a URL that grows with the
-- guest list and eventually stops being a valid request.
--
-- Keyset paginated on the same terms as the unfiltered walk — ordered by
-- token, strictly greater than the cursor — so the caller's resume logic
-- is identical whichever audience it is addressing. Offset pagination
-- would skip devices whenever a dead token ahead of the cursor is pruned
-- mid-walk.
create or replace function public.session_audience_tokens(
  p_session_id uuid,
  p_after text default null,
  p_limit int default 500
)
returns table (token text)
language sql
stable
security definer
set search_path = public
as $$
  select t.token
  from public.push_tokens t
  join public.workshop_registrations r
    on r.user_id = t.user_id
   and r.live_session_id = p_session_id
   and r.status = 'paid'
  where p_after is null or t.token > p_after
  order by t.token
  limit p_limit;
$$;

revoke execute on function public.session_audience_tokens(uuid, text, int)
  from public, anon, authenticated;
grant execute on function public.session_audience_tokens(uuid, text, int)
  to service_role;
