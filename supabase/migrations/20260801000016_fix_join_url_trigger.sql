-- Fix: creating a paid session failed on a foreign key.
--
-- protect_paid_join_url() ran BEFORE INSERT and wrote a row into
-- live_session_join_links keyed on new.id. On an insert that row does
-- not exist in live_sessions yet — BEFORE means before the parent is
-- written — so the foreign key had nothing to point at and the whole
-- insert was rejected. Updates worked, which is why the mistake was not
-- obvious: the parent already exists by then.
--
-- Moved to AFTER, where the parent is guaranteed. An AFTER trigger
-- cannot assign to NEW, so blanking the public column becomes its own
-- UPDATE. That re-fires this trigger once; the guards below make the
-- second pass a no-op, so it terminates rather than recursing.

create or replace function public.protect_paid_join_url()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_stored text;
begin
  if coalesce(new.price_amount, 0) > 0 then
    -- Paid. Stash the link, then blank the column members can read.
    --
    -- Guarded on the link being present so the recursive pass — which
    -- sees join_url = '' — does nothing and stops here.
    if new.join_url is not null and new.join_url <> '' then
      insert into public.live_session_join_links (session_id, join_url)
      values (new.id, new.join_url)
      on conflict (session_id)
        do update set join_url = excluded.join_url, updated_at = now();

      update public.live_sessions
         set join_url = ''
       where id = new.id;
    end if;
  else
    -- Free, or the price was just removed. Put the link back where every
    -- client already looks for it.
    select l.join_url into v_stored
    from public.live_session_join_links l
    where l.session_id = new.id;

    if v_stored is not null then
      -- Same guard in reverse: on the recursive pass join_url is no
      -- longer blank, so the restore does not repeat.
      if new.join_url is null or new.join_url = '' then
        update public.live_sessions
           set join_url = v_stored
         where id = new.id;
      end if;

      delete from public.live_session_join_links where session_id = new.id;
    end if;
  end if;

  -- AFTER triggers ignore the return value; null is the convention.
  return null;
end;
$$;

drop trigger if exists trg_live_sessions_protect_join_url on public.live_sessions;
create trigger trg_live_sessions_protect_join_url
  after insert or update on public.live_sessions
  for each row execute function public.protect_paid_join_url();
