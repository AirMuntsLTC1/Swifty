-- Swifly: feed, replies and RLS fix.
-- Safe to run more than once. Run in Supabase Dashboard -> SQL Editor.

-- 1. Replies can carry an image (the app stores the public URL here).
alter table public.comments add column if not exists image_url text;

-- 2. Indexes for the feed, thread and profile queries.
create index if not exists posts_created_at_idx on public.posts (created_at desc);
create index if not exists posts_author_created_idx on public.posts (author_id, created_at desc);
create index if not exists comments_post_created_idx on public.comments (post_id, created_at);
create index if not exists post_media_post_position_idx on public.post_media (post_id, position);

-- 3. Insert policies: each one states who may write the row, explicitly.
--    Without WITH CHECK an insert can be rejected or accepted unpredictably.

drop policy if exists swifs_posts_insert_own on public.posts;
create policy swifs_posts_insert_own on public.posts
  for insert to authenticated
  with check (author_id = auth.uid());

drop policy if exists swifs_comments_insert_own on public.comments;
create policy swifs_comments_insert_own on public.comments
  for insert to authenticated
  with check (
    author_id = auth.uid()
    and exists (select 1 from public.posts p where p.id = comments.post_id)
  );

drop policy if exists swifs_post_media_insert_author on public.post_media;
create policy swifs_post_media_insert_author on public.post_media
  for insert to authenticated
  with check (
    exists (select 1 from public.posts p
            where p.id = post_media.post_id and p.author_id = auth.uid())
  );

drop policy if exists swifs_post_likes_insert_own on public.post_likes;
create policy swifs_post_likes_insert_own on public.post_likes
  for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists swifs_post_saves_insert_own on public.post_saves;
create policy swifs_post_saves_insert_own on public.post_saves
  for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists swifs_comment_likes_insert_own on public.comment_likes;
create policy swifs_comment_likes_insert_own on public.comment_likes
  for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists swifs_follows_insert_own on public.follows;
create policy swifs_follows_insert_own on public.follows
  for insert to authenticated
  with check (follower = auth.uid());

drop policy if exists swifs_profiles_insert_own on public.profiles;
create policy swifs_profiles_insert_own on public.profiles
  for insert to authenticated
  with check (id = auth.uid());

drop policy if exists swifs_blocked_insert_own on public.blocked_users;
create policy swifs_blocked_insert_own on public.blocked_users
  for insert to authenticated
  with check (blocker = auth.uid());

drop policy if exists swifs_restricted_insert_own on public.restricted_users;
create policy swifs_restricted_insert_own on public.restricted_users
  for insert to authenticated
  with check (restrictor = auth.uid());

drop policy if exists swifs_messages_insert on public.messages;
create policy swifs_messages_insert on public.messages
  for insert to authenticated
  with check (sender = auth.uid());

drop policy if exists swifs_message_reactions_insert_own on public.message_reactions;
create policy swifs_message_reactions_insert_own on public.message_reactions
  for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists swifs_message_reports_insert on public.message_reports;
create policy swifs_message_reports_insert on public.message_reports
  for insert to authenticated
  with check (reporter = auth.uid());

drop policy if exists swifs_stories_insert_own on public.stories;
create policy swifs_stories_insert_own on public.stories
  for insert to authenticated
  with check (author_id = auth.uid());

drop policy if exists swifs_story_views_insert_own on public.story_views;
create policy swifs_story_views_insert_own on public.story_views
  for insert to authenticated
  with check (viewer_id = auth.uid());

drop policy if exists swifs_story_reactions_insert_own on public.story_reactions;
create policy swifs_story_reactions_insert_own on public.story_reactions
  for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists swifs_story_replies_insert_own on public.story_replies;
create policy swifs_story_replies_insert_own on public.story_replies
  for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists swifs_user_settings_insert_own on public.user_settings;
create policy swifs_user_settings_insert_own on public.user_settings
  for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists swifs_groups_insert_admin on public.groups;
create policy swifs_groups_insert_admin on public.groups
  for insert to authenticated
  with check (admin_id = auth.uid());

drop policy if exists swifs_group_members_insert on public.group_members;
create policy swifs_group_members_insert on public.group_members
  for insert to authenticated
  with check (user_id = auth.uid() or public.is_group_admin(group_id));

-- 4. Comments: anyone who can see the post can read its replies.
drop policy if exists swifs_comments_read on public.comments;
create policy swifs_comments_read on public.comments
  for select to authenticated
  using (exists (select 1 from public.posts p where p.id = comments.post_id));

-- 5. Authors can edit and delete their own replies; post owners can moderate.
drop policy if exists swifs_comments_delete on public.comments;
create policy swifs_comments_delete on public.comments
  for delete to authenticated
  using (
    author_id = auth.uid()
    or exists (select 1 from public.posts p
               where p.id = comments.post_id and p.author_id = auth.uid())
  );

-- 6. Realtime: make sure the feed tables publish changes.
do $$
declare t text;
begin
  foreach t in array array['posts','comments','post_likes','post_media','notifications']
  loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- 7. Storage: public read; signed-in users write only inside their own folder.
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


