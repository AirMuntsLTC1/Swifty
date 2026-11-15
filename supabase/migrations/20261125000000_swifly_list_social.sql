-- Swifly: list membership, join requests, posts in lists, list notifications,
-- and live unread counts for the red badges.
-- Safe to run more than once. Run after 20261124000000_swifly_lists.sql.

-- 1. Posts can be added to a list ---------------------------------------------
alter table public.posts
  add column if not exists list_id uuid references public.lists (id) on delete set null;
create index if not exists posts_list_idx on public.posts (list_id, created_at desc);

-- 2. Join requests for private lists -----------------------------------------
create table if not exists public.list_join_requests (
  list_id    uuid not null references public.lists (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  status     text not null default 'pending' check (status in ('pending', 'approved', 'declined')),
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  decided_by uuid references public.profiles (id) on delete set null,
  primary key (list_id, user_id)
);
create index if not exists list_join_requests_pending_idx
  on public.list_join_requests (list_id, status);

alter table public.list_join_requests enable row level security;
revoke all on public.list_join_requests from anon, authenticated;
grant select on public.list_join_requests to authenticated;

drop policy if exists swifly_list_join_requests_select on public.list_join_requests;
create policy swifly_list_join_requests_select on public.list_join_requests
  for select to authenticated
  using (user_id = auth.uid() or public.swifly_is_list_editor(list_id));

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'list_join_requests'
  ) then
    alter publication supabase_realtime add table public.list_join_requests;
  end if;
end $$;

-- 3. Visibility ----------------------------------------------------------------
-- Card: the name, description, cover and icon of a list. Anyone who is not
-- blocked can see a card, so people can find a private list and ask to join.
create or replace function public.swifly_can_see_list_card(p_list uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.lists l
    where l.id = p_list
      and (
        l.owner_id = auth.uid()
        or public.swifly_is_list_editor(l.id)
        or exists (select 1 from public.list_members m where m.list_id = l.id and m.user_id = auth.uid())
        or not coalesce(public.is_blocked_between(auth.uid(), l.owner_id), false)
      )
  );
$$;

-- Contents (members, timeline): owner, collaborators, members, and anyone on a
-- public list who is not blocked.
create or replace function public.swifly_can_view_list(p_list uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.lists l
    where l.id = p_list
      and (
        l.owner_id = auth.uid()
        or public.swifly_is_list_editor(l.id)
        or exists (select 1 from public.list_members m where m.list_id = l.id and m.user_id = auth.uid())
        or (not l.is_private and not coalesce(public.is_blocked_between(auth.uid(), l.owner_id), false))
      )
  );
$$;

drop policy if exists swifly_lists_select on public.lists;
create policy swifly_lists_select on public.lists
  for select to authenticated
  using (public.swifly_can_see_list_card(id));

-- 4. Notifications: one trigger per list event ----------------------------------

-- A public join (the member added themselves). The accept path sets the
-- 'swifly.skip_join_notify' flag so an accepted request notifies only the requester.
create or replace function public.swifly_on_list_join()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  l_name text;
  j_handle text;
  j_name text;
  j_avatar text;
begin
  if coalesce(current_setting('swifly.skip_join_notify', true), 'off') = 'on' then
    return new;
  end if;
  if new.added_by is distinct from new.user_id then
    return new;
  end if;
  begin
    select l.name into l_name from public.lists l where l.id = new.list_id;
    select p.username, p.display_name, p.avatar_url into j_handle, j_name, j_avatar
      from public.profiles p where p.id = new.user_id;
    insert into public.notifications
      (user_id, type, actor_id, actor_handle, actor_name, avatar_url, preview, list_id, read)
    select x.uid, 'list_join', new.user_id, coalesce(j_handle, ''),
           coalesce(j_name, j_handle, ''), j_avatar, l_name, new.list_id, false
    from (
      select l.owner_id as uid from public.lists l where l.id = new.list_id
      union
      select e.user_id from public.list_editors e where e.list_id = new.list_id
    ) x
    where x.uid <> new.user_id;
  exception when others then
    null; -- never block the join itself
  end;
  return new;
end;
$$;

drop trigger if exists swifly_list_join_notify on public.list_members;
create trigger swifly_list_join_notify
  after insert on public.list_members
  for each row execute function public.swifly_on_list_join();

-- A new pending request (for a private list) notifies the owner and collaborators.
create or replace function public.swifly_on_list_request()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  l_name text;
  r_handle text;
  r_name text;
  r_avatar text;
begin
  if new.status <> 'pending' then
    return new;
  end if;
  if tg_op = 'UPDATE' and old.status = 'pending' then
    return new;
  end if;
  begin
    select l.name into l_name from public.lists l where l.id = new.list_id;
    select p.username, p.display_name, p.avatar_url into r_handle, r_name, r_avatar
      from public.profiles p where p.id = new.user_id;
    insert into public.notifications
      (user_id, type, actor_id, actor_handle, actor_name, avatar_url, preview, list_id, read)
    select x.uid, 'list_request', new.user_id, coalesce(r_handle, ''),
           coalesce(r_name, r_handle, ''), r_avatar, l_name, new.list_id, false
    from (
      select l.owner_id as uid from public.lists l where l.id = new.list_id
      union
      select e.user_id from public.list_editors e where e.list_id = new.list_id
    ) x
    where x.uid <> new.user_id;
  exception when others then
    null;
  end;
  return new;
end;
$$;

drop trigger if exists swifly_list_request_notify on public.list_join_requests;
create trigger swifly_list_request_notify
  after insert or update of status on public.list_join_requests
  for each row execute function public.swifly_on_list_request();

-- 5. Functions the app calls ----------------------------------------------------

-- Join a list. Public: you become a member at once and the function returns
-- 'joined'. Private: a request is sent and the function returns 'requested'.
create or replace function public.swifly_join_list(p_list uuid)
returns text
language plpgsql
security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
  l_owner uuid;
  l_private boolean;
begin
  if me is null then
    raise exception 'You are not signed in';
  end if;
  select l.owner_id, l.is_private into l_owner, l_private from public.lists l where l.id = p_list;
  if not found then
    raise exception 'This list no longer exists';
  end if;
  if l_owner = me then
    raise exception 'You own this list';
  end if;
  if not public.swifly_can_see_list_card(p_list) then
    raise exception 'This list is not available';
  end if;
  if exists (select 1 from public.list_members m where m.list_id = p_list and m.user_id = me) then
    return 'joined';
  end if;

  if l_private then
    insert into public.list_join_requests (list_id, user_id, status, created_at)
    values (p_list, me, 'pending', now())
    on conflict (list_id, user_id) do update
      set status = 'pending', created_at = now(), decided_at = null, decided_by = null
      where public.list_join_requests.status <> 'pending';
    return 'requested';
  end if;

  insert into public.list_members (list_id, user_id, added_by)
  values (p_list, me, me)
  on conflict (list_id, user_id) do nothing;
  insert into public.list_follows (list_id, user_id)
  values (p_list, me)
  on conflict (list_id, user_id) do nothing;
  return 'joined';
end;
$$;

create or replace function public.swifly_leave_list(p_list uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'You are not signed in';
  end if;
  if exists (select 1 from public.lists l where l.id = p_list and l.owner_id = me) then
    raise exception 'The owner cannot leave their own list';
  end if;
  delete from public.list_members where list_id = p_list and user_id = me;
  delete from public.list_editors where list_id = p_list and user_id = me;
end;
$$;

create or replace function public.swifly_cancel_join_request(p_list uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'You are not signed in';
  end if;
  delete from public.list_join_requests
   where list_id = p_list and user_id = auth.uid() and status = 'pending';
end;
$$;

-- Owner or collaborator accepts or declines a pending request.
-- Accepting adds the member and tells only the requester.
create or replace function public.swifly_respond_join_request(
  p_list uuid,
  p_user uuid,
  p_accept boolean
)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
  l_name text;
  a_handle text;
  a_name text;
  a_avatar text;
begin
  if me is null then
    raise exception 'You are not signed in';
  end if;
  if not public.swifly_is_list_editor(p_list) then
    raise exception 'Only the owner and collaborators can respond to requests';
  end if;
  if not exists (
    select 1 from public.list_join_requests r
    where r.list_id = p_list and r.user_id = p_user and r.status = 'pending'
  ) then
    raise exception 'That request is no longer pending';
  end if;

  if coalesce(p_accept, false) then
    perform set_config('swifly.skip_join_notify', 'on', true);
    insert into public.list_members (list_id, user_id, added_by)
    values (p_list, p_user, p_user)
    on conflict (list_id, user_id) do nothing;
    perform set_config('swifly.skip_join_notify', 'off', true);

    insert into public.list_follows (list_id, user_id)
    values (p_list, p_user)
    on conflict (list_id, user_id) do nothing;

    update public.list_join_requests
       set status = 'approved', decided_at = now(), decided_by = me
     where list_id = p_list and user_id = p_user;

    begin
      select l.name into l_name from public.lists l where l.id = p_list;
      select p.username, p.display_name, p.avatar_url into a_handle, a_name, a_avatar
        from public.profiles p where p.id = me;
      insert into public.notifications
        (user_id, type, actor_id, actor_handle, actor_name, avatar_url, preview, list_id, read)
      values
        (p_user, 'list_request_accepted', me, coalesce(a_handle, ''),
         coalesce(a_name, a_handle, ''), a_avatar, l_name, p_list, false);
    exception when others then
      null;
    end;
  else
    update public.list_join_requests
       set status = 'declined', decided_at = now(), decided_by = me
     where list_id = p_list and user_id = p_user;
  end if;
end;
$$;

-- Tag one of your own posts to a list you belong to. Members and collaborators
-- are told about it (not the author, and not people they have blocked).
create or replace function public.swifly_tag_post_to_list(p_post uuid, p_list uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
  l_name text;
  a_handle text;
  a_name text;
  a_avatar text;
begin
  if me is null then
    raise exception 'You are not signed in';
  end if;
  if not exists (select 1 from public.posts p where p.id = p_post and p.author_id = me) then
    raise exception 'You can only add your own posts to a list';
  end if;
  if not (
    public.swifly_is_list_editor(p_list)
    or exists (select 1 from public.list_members m where m.list_id = p_list and m.user_id = me)
  ) then
    raise exception 'Join this list before you post to it';
  end if;

  update public.posts set list_id = p_list where id = p_post;

  begin
    select l.name into l_name from public.lists l where l.id = p_list;
    select p.username, p.display_name, p.avatar_url into a_handle, a_name, a_avatar
      from public.profiles p where p.id = me;
    insert into public.notifications
      (user_id, type, actor_id, actor_handle, actor_name, avatar_url, preview, list_id, read)
    select x.uid, 'list_post', me, coalesce(a_handle, ''),
           coalesce(a_name, a_handle, ''), a_avatar, l_name, p_list, false
    from (
      select l.owner_id as uid from public.lists l where l.id = p_list
      union
      select m.user_id from public.list_members m where m.list_id = p_list
      union
      select e.user_id from public.list_editors e where e.list_id = p_list
    ) x
    where x.uid <> me
      and not exists (
        select 1 from public.blocked_users b
        where (b.blocker = x.uid and b.blocked = me) or (b.blocker = me and b.blocked = x.uid)
      );
  exception when others then
    null;
  end;
end;
$$;

-- Unread counts for the red badges (notifications and direct messages).
create or replace function public.swifly_unread_counts()
returns table (notifications integer, messages integer)
language sql stable security definer set search_path = public
as $$
  select
    (select count(*)::int from public.notifications n
       where n.user_id = auth.uid() and not coalesce(n.read, false)),
    (select count(*)::int from public.messages m
       where m.recipient = auth.uid() and m.read_at is null);
$$;

-- 6. Lock the function API to signed-in users ----------------------------------
revoke all on function public.swifly_join_list(uuid) from public, anon;
revoke all on function public.swifly_leave_list(uuid) from public, anon;
revoke all on function public.swifly_cancel_join_request(uuid) from public, anon;
revoke all on function public.swifly_respond_join_request(uuid, uuid, boolean) from public, anon;
revoke all on function public.swifly_tag_post_to_list(uuid, uuid) from public, anon;
revoke all on function public.swifly_unread_counts() from public, anon;

grant execute on function public.swifly_join_list(uuid) to authenticated;
grant execute on function public.swifly_leave_list(uuid) to authenticated;
grant execute on function public.swifly_cancel_join_request(uuid) to authenticated;
grant execute on function public.swifly_respond_join_request(uuid, uuid, boolean) to authenticated;
grant execute on function public.swifly_tag_post_to_list(uuid, uuid) to authenticated;
grant execute on function public.swifly_unread_counts() to authenticated;




