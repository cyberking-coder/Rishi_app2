-- Public storage bucket for cover art / thumbnails.
--
-- Unlike the audio masters (private R2, served via short-lived presigned
-- URLs), cover images are loaded directly by the app with Image.network,
-- so they live in a PUBLIC bucket and are safe to expose. Uploads happen
-- only via the admin (service role), which bypasses RLS.

insert into storage.buckets (id, name, public)
values ('covers', 'covers', true)
on conflict (id) do nothing;

-- Anyone may read cover images (the bucket is public). Writes are performed
-- by the admin dashboard using the service-role key, which bypasses RLS, so
-- no insert/update policy is required for ordinary users.
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'covers_public_read'
  ) then
    create policy "covers_public_read"
      on storage.objects for select
      using (bucket_id = 'covers');
  end if;
end $$;
