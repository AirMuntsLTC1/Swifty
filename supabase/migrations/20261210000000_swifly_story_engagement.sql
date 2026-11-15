-- Swifly: likes and reposts on Moments (stories).
-- Comments use the existing story_replies table.
-- Run in Supabase Dashboard -> SQL Editor, or supabase db push.

create table if not exists public.story_likes (
  story_id uuid not null references public.stories(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (story_id, user_id)
);

create table if not exists public.story_reposts (
  story_id uuid not null references public.stories(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (story_id, user_id)
);

alter table public.story_likes enable row level security;
alter table public.story_reposts enable row level security;

-- Anyone signed in can see the counts. You can only add or remove your own row.
drop policy if exists swifs_story_likes_read on public.story_likes;
create policy swifs_story_likes_read on public.story_likes
  for select to authenticated using (true);
drop policy if exists swifs_story_likes_insert_own on public.story_likes;
create policy swifs_story_likes_insert_own on public.story_likes
  for insert to authenticated with check (user_id = auth.uid());
drop policy if exists swifs_story_likes_delete_own on public.story_likes;
create policy swifs_story_likes_delete_own on public.story_likes
  for delete to authenticated using (user_id = auth.uid());

drop policy if exists swifs_story_reposts_read on public.story_reposts;
create policy swifs_story_reposts_read on public.story_reposts
  for select to authenticated using (true);
drop policy if exists swifs_story_reposts_insert_own on public.story_reposts;
create policy swifs_story_reposts_insert_own on public.story_reposts
  for insert to authenticated with check (user_id = auth.uid());
drop policy if exists swifs_story_reposts_delete_own on public.story_reposts;
create policy swifs_story_reposts_delete_own on public.story_reposts
  for delete to authenticated using (user_id = auth.uid());
