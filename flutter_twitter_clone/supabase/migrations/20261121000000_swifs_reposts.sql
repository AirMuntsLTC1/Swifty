-- Swifs: retweets. One row per user per post; posts.shares is the count.
-- Safe to run more than once. Run in Supabase Dashboard -> SQL Editor.

create table if not exists public.post_reposts (
  post_id uuid not null references public.posts (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

alter table public.post_reposts enable row level security;

drop policy if exists swifs_post_reposts_read on public.post_reposts;
create policy swifs_post_reposts_read on public.post_reposts
  for select to authenticated using (true);

drop policy if exists swifs_post_reposts_insert_own on public.post_reposts;
create policy swifs_post_reposts_insert_own on public.post_reposts
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists swifs_post_reposts_delete_own on public.post_reposts;
create policy swifs_post_reposts_delete_own on public.post_reposts
  for delete to authenticated using (user_id = auth.uid());

-- Keep posts.shares equal to the number of reposts.
create or replace function public.swifs_sync_post_shares()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    update public.posts
       set shares = (select count(*) from public.post_reposts where post_id = old.post_id)
     where id = old.post_id;
    return old;
  end if;
  update public.posts
     set shares = (select count(*) from public.post_reposts where post_id = new.post_id)
   where id = new.post_id;
  return new;
end;
$$;

drop trigger if exists swifs_post_reposts_sync on public.post_reposts;
create trigger swifs_post_reposts_sync
  after insert or delete on public.post_reposts
  for each row execute function public.swifs_sync_post_shares();

-- Feed counts update live.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'post_reposts'
  ) then
    alter publication supabase_realtime add table public.post_reposts;
  end if;
end $$;


