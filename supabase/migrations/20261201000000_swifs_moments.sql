-- Swifs Moments: hardening for 24-hour stories, reactions and replies.
-- Safe to run more than once. Run in Supabase Dashboard -> SQL Editor.

-- 1. Every story expires 24 hours after it is posted, even if the app forgets.
alter table public.stories
  alter column expires_at set default (now() + interval '24 hours');

-- 2. Fast ring query: active stories, newest first.
create index if not exists stories_expires_created_idx
  on public.stories (expires_at, created_at desc);

-- 3. One reaction per viewer per story. Remove duplicates first so the
--    unique index can be created.
delete from public.story_reactions a
using public.story_reactions b
where a.story_id = b.story_id
  and a.user_id = b.user_id
  and a.ctid < b.ctid;

create unique index if not exists story_reactions_story_user_key
  on public.story_reactions (story_id, user_id);

-- 4. Changing your own reaction must be allowed (the app upserts it).
--    Without this policy the upsert is rejected by RLS.
drop policy if exists swifs_story_reactions_update_own on public.story_reactions;
create policy swifs_story_reactions_update_own on public.story_reactions
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- 5. Keep emoji values short (a single emoji is at most a few code points).
do $$
begin
  alter table public.story_reactions
    add constraint story_reactions_emoji_len
    check (char_length(emoji) between 1 and 8);
exception
  when duplicate_object then null;
end $$;

-- 6. Replies must have text.
do $$
begin
  alter table public.story_replies
    add constraint story_replies_text_len
    check (char_length(trim(text)) between 1 and 500);
exception
  when duplicate_object then null;
end $$;




