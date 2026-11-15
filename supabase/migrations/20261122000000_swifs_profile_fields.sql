-- Swifs: profile banner, location and date of birth.
-- Safe to run more than once. Run in Supabase Dashboard -> SQL Editor.

alter table public.profiles
  add column if not exists cover_url text,
  add column if not exists location text,
  add column if not exists date_of_birth date;

-- Banner images live in a public bucket, like avatars.
insert into storage.buckets (id, name, public)
values ('covers', 'covers', true)
on conflict (id) do nothing;

-- Storage rules: anyone can read the public buckets; signed-in users may
-- write only inside their own folder ("<user id>/file.jpg").
drop policy if exists "swifly_objects_read" on storage.objects;
create policy "swifly_objects_read" on storage.objects
  for select to public
  using (bucket_id in ('post-media', 'avatars', 'stories', 'covers'));

drop policy if exists "swifly_objects_insert_own_folder" on storage.objects;
create policy "swifly_objects_insert_own_folder" on storage.objects
  for insert to authenticated
  with check (
    bucket_id in ('post-media', 'avatars', 'stories', 'covers')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "swifly_objects_update_own_folder" on storage.objects;
create policy "swifly_objects_update_own_folder" on storage.objects
  for update to authenticated
  using (
    bucket_id in ('post-media', 'avatars', 'stories', 'covers')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "swifly_objects_delete_own_folder" on storage.objects;
create policy "swifly_objects_delete_own_folder" on storage.objects
  for delete to authenticated
  using (
    bucket_id in ('post-media', 'avatars', 'stories', 'covers')
    and (storage.foldername(name))[1] = auth.uid()::text
  );
