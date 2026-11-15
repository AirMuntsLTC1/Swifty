-- Swifly: connects the Flutter app (Supabase only) to the existing schema.
-- Safe to run more than once. Run in Supabase Dashboard -> SQL Editor.

-- 1. Device push tokens. The app cannot insert into user_devices directly
--    (no insert policy), so it calls this SECURITY DEFINER function instead.
create or replace function public.swifly_register_push_token(p_token text, p_platform text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  insert into public.user_devices (token, user_id, platform, updated_at)
  values (p_token, auth.uid(), p_platform, now())
  on conflict (token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        updated_at = now();
end;
$$;

revoke all on function public.swifly_register_push_token(text, text) from public, anon;
grant execute on function public.swifly_register_push_token(text, text) to authenticated;

-- 2. Storage: signed-in users may upload only into their own folder
--    ("<user id>/file.jpg") in the post-media, avatars and stories buckets.
--    Public buckets already serve files by URL; these policies allow the upload
--    and the read used by the app.
drop policy if exists "swifly_objects_read" on storage.objects;
create policy "swifly_objects_read" on storage.objects
  for select to public
  using (bucket_id in ('post-media', 'avatars', 'stories'));

drop policy if exists "swifly_objects_insert_own_folder" on storage.objects;
create policy "swifly_objects_insert_own_folder" on storage.objects
  for insert to authenticated
  with check (
    bucket_id in ('post-media', 'avatars', 'stories')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "swifly_objects_update_own_folder" on storage.objects;
create policy "swifly_objects_update_own_folder" on storage.objects
  for update to authenticated
  using (
    bucket_id in ('post-media', 'avatars', 'stories')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "swifly_objects_delete_own_folder" on storage.objects;
create policy "swifly_objects_delete_own_folder" on storage.objects
  for delete to authenticated
  using (
    bucket_id in ('post-media', 'avatars', 'stories')
    and (storage.foldername(name))[1] = auth.uid()::text
  );




