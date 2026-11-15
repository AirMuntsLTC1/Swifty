-- Swifly: Lists (curated accounts, list timelines, followers, pins, collaborators).
-- Safe to run more than once. Run in Supabase Dashboard -> SQL Editor.
--
-- Every write goes through a SECURITY DEFINER function below. The app never
-- writes these tables directly, so the rules live in one place.

-- 1. Tables ------------------------------------------------------------------

create table if not exists public.lists (
  id             uuid primary key default gen_random_uuid(),
  owner_id       uuid not null references public.profiles (id) on delete cascade,
  name           text not null check (char_length(btrim(name)) between 1 and 40),
  description    text not null default '' check (char_length(description) <= 160),
  icon           text not null default 'list'
                 check (icon in ('list','news','code','music','camera','heart',
                                 'star','globe','briefcase','book','game','trending')),
  cover_url      text,
  is_private     boolean not null default false,
  member_count   integer not null default 0,
  follower_count integer not null default 0,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index if not exists lists_owner_idx on public.lists (owner_id);
create index if not exists lists_popular_idx on public.lists (is_private, follower_count desc);

-- Accounts on the list. Their posts make up the list timeline.
create table if not exists public.list_members (
  list_id    uuid not null references public.lists (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  added_by   uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (list_id, user_id)
);
create index if not exists list_members_user_idx on public.list_members (user_id);

-- People who follow a public list.
create table if not exists public.list_follows (
  list_id    uuid not null references public.lists (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (list_id, user_id)
);
create index if not exists list_follows_user_idx on public.list_follows (user_id);

-- Collaborators: can add and remove members with the owner.
create table if not exists public.list_editors (
  list_id    uuid not null references public.lists (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  invited_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (list_id, user_id)
);
create index if not exists list_editors_user_idx on public.list_editors (user_id);

-- A user's pinned lists (max 5, enforced in swifly_set_list_pin).
create table if not exists public.list_pins (
  user_id    uuid not null references public.profiles (id) on delete cascade,
  list_id    uuid not null references public.lists (id) on delete cascade,
  position   integer not null default 0,
  created_at timestamptz not null default now(),
  primary key (user_id, list_id)
);

-- Notifications can point at a list (type 'list_add').
alter table public.notifications
  add column if not exists list_id uuid references public.lists (id) on delete cascade;
create index if not exists notifications_list_idx on public.notifications (list_id);

-- 2. Access helpers ----------------------------------------------------------
-- SECURITY DEFINER so policies can check membership without recursing into
-- the policies of the tables they read.

create or replace function public.swifly_is_list_owner(p_list uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.lists l
    where l.id = p_list and l.owner_id = auth.uid()
  );
$$;

create or replace function public.swifly_is_list_editor(p_list uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select public.swifly_is_list_owner(p_list)
      or exists (
        select 1 from public.list_editors e
        where e.list_id = p_list and e.user_id = auth.uid()
      );
$$;

-- Owner and collaborators always see the list. Everyone else sees a public
-- list, unless the owner has blocked them or they have blocked the owner.
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
        or (
          not l.is_private
          and not coalesce(public.is_blocked_between(auth.uid(), l.owner_id), false)
        )
      )
  );
$$;

-- 3. Triggers ----------------------------------------------------------------

create or replace function public.swifly_touch_list()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists swifly_lists_touch on public.lists;
create trigger swifly_lists_touch
  before update on public.lists
  for each row execute function public.swifly_touch_list();

-- Keep lists.member_count equal to the number of members.
create or replace function public.swifly_sync_list_member_count()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  lid uuid;
begin
  if tg_op = 'DELETE' then lid := old.list_id; else lid := new.list_id; end if;
  update public.lists
     set member_count = (select count(*) from public.list_members m where m.list_id = lid)
   where id = lid;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

drop trigger if exists swifly_list_members_count on public.list_members;
create trigger swifly_list_members_count
  after insert or delete on public.list_members
  for each row execute function public.swifly_sync_list_member_count();

-- Keep lists.follower_count equal to the number of followers.
create or replace function public.swifly_sync_list_follower_count()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  lid uuid;
begin
  if tg_op = 'DELETE' then lid := old.list_id; else lid := new.list_id; end if;
  update public.lists
     set follower_count = (select count(*) from public.list_follows f where f.list_id = lid)
   where id = lid;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

drop trigger if exists swifly_list_follows_count on public.list_follows;
create trigger swifly_list_follows_count
  after insert or delete on public.list_follows
  for each row execute function public.swifly_sync_list_follower_count();

-- Tell someone when they are added to a PUBLIC list. Private lists stay quiet.
-- Skipped when the person added themselves or either side has blocked the other.
create or replace function public.swifly_on_list_member_added()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  l_name text;
  l_private boolean;
  a_handle text;
  a_name text;
  a_avatar text;
begin
  select l.name, l.is_private into l_name, l_private
    from public.lists l where l.id = new.list_id;
  if not found or l_private then
    return new;
  end if;
  if new.added_by is null or new.added_by = new.user_id then
    return new;
  end if;
  if coalesce(public.is_blocked_between(new.added_by, new.user_id), false) then
    return new;
  end if;

  select p.username, p.display_name, p.avatar_url
    into a_handle, a_name, a_avatar
    from public.profiles p where p.id = new.added_by;

  -- A notification must never block adding someone to a list, so any problem
  -- writing it (for example an existing check constraint on notifications.type)
  -- is ignored here.
  begin
    insert into public.notifications
      (user_id, type, actor_id, actor_handle, actor_name, avatar_url, preview, list_id, read)
    values
      (new.user_id, 'list_add', new.added_by, coalesce(a_handle, ''),
       coalesce(a_name, a_handle, ''), a_avatar, l_name, new.list_id, false);
  exception when others then
    null;
  end;
  return new;
end;
$$;

drop trigger if exists swifly_list_member_added on public.list_members;
create trigger swifly_list_member_added
  after insert on public.list_members
  for each row execute function public.swifly_on_list_member_added();

-- 4. Functions the app calls (RPC) -----------------------------------------

create or replace function public.swifly_create_list(
  p_name text,
  p_description text default '',
  p_icon text default 'list',
  p_cover_url text default '',
  p_is_private boolean default false
)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
  clean_name text := btrim(coalesce(p_name, ''));
  new_id uuid;
begin
  if me is null then
    raise exception 'You are not signed in';
  end if;
  if char_length(clean_name) < 1 then
    raise exception 'Give your list a name';
  end if;
  if char_length(clean_name) > 40 then
    raise exception 'List names can be at most 40 characters';
  end if;
  if char_length(coalesce(p_description, '')) > 160 then
    raise exception 'Descriptions can be at most 160 characters';
  end if;

  insert into public.lists (owner_id, name, description, icon, cover_url, is_private)
  values (
    me,
    clean_name,
    btrim(coalesce(p_description, '')),
    coalesce(p_icon, 'list'),
    nullif(p_cover_url, ''),
    coalesce(p_is_private, false)
  )
  returning id into new_id;

  return new_id;
end;
$$;

create or replace function public.swifly_update_list(
  p_list uuid,
  p_name text,
  p_description text,
  p_icon text,
  p_cover_url text,
  p_is_private boolean
)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
  clean_name text := btrim(coalesce(p_name, ''));
  was_private boolean;
begin
  if me is null then
    raise exception 'You are not signed in';
  end if;
  if not exists (select 1 from public.lists where id = p_list and owner_id = me) then
    raise exception 'Only the list owner can edit this list';
  end if;
  if char_length(clean_name) < 1 or char_length(clean_name) > 40 then
    raise exception 'List names must be 1 to 40 characters';
  end if;
  if char_length(coalesce(p_description, '')) > 160 then
    raise exception 'Descriptions can be at most 160 characters';
  end if;

  select l.is_private into was_private from public.lists l where l.id = p_list;

  update public.lists
     set name        = clean_name,
         description = btrim(coalesce(p_description, '')),
         icon        = coalesce(p_icon, icon),
         cover_url   = case when p_cover_url is null then cover_url else nullif(p_cover_url, '') end,
         is_private  = coalesce(p_is_private, is_private)
   where id = p_list;

  -- Going private ends every follow: only the owner and collaborators see it now.
  if coalesce(p_is_private, false) and not was_private then
    delete from public.list_follows where list_id = p_list;
    delete from public.list_pins where list_id = p_list and user_id <> me;
  end if;
end;
$$;

create or replace function public.swifly_delete_list(p_list uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'You are not signed in';
  end if;
  if not exists (select 1 from public.lists where id = p_list and owner_id = auth.uid()) then
    raise exception 'Only the list owner can delete this list';
  end if;
  delete from public.lists where id = p_list;
end;
$$;

create or replace function public.swifly_add_list_member(p_list uuid, p_user uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
  owner_uuid uuid;
begin
  if me is null then
    raise exception 'You are not signed in';
  end if;
  select l.owner_id into owner_uuid from public.lists l where l.id = p_list;
  if owner_uuid is null then
    raise exception 'This list no longer exists';
  end if;
  if not (owner_uuid = me or public.swifly_is_list_editor(p_list)) then
    raise exception 'Only the owner and collaborators can add people to this list';
  end if;
  if p_user = owner_uuid then
    raise exception 'The owner is already on this list';
  end if;
  if not exists (select 1 from public.profiles where id = p_user) then
    raise exception 'That account does not exist';
  end if;
  if coalesce(public.is_blocked_between(me, p_user), false) then
    raise exception 'You cannot add this account';
  end if;

  insert into public.list_members (list_id, user_id, added_by)
  values (p_list, p_user, me)
  on conflict (list_id, user_id) do nothing;
end;
$$;

create or replace function public.swifly_remove_list_member(p_list uuid, p_user uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'You are not signed in';
  end if;
  -- People may always take themselves off a list.
  if p_user <> auth.uid() and not public.swifly_is_list_editor(p_list) then
    raise exception 'Only the owner and collaborators can remove people from this list';
  end if;
  delete from public.list_members where list_id = p_list and user_id = p_user;
end;
$$;

create or replace function public.swifly_set_list_editor(p_list uuid, p_user uuid, p_on boolean)
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
  if not exists (select 1 from public.lists where id = p_list and owner_id = me) then
    raise exception 'Only the owner can add or remove collaborators';
  end if;
  if p_user = me then
    raise exception 'You already own this list';
  end if;

  if coalesce(p_on, false) then
    if not exists (select 1 from public.profiles where id = p_user) then
      raise exception 'That account does not exist';
    end if;
    if coalesce(public.is_blocked_between(me, p_user), false) then
      raise exception 'You cannot add this account';
    end if;
    insert into public.list_editors (list_id, user_id, invited_by)
    values (p_list, p_user, me)
    on conflict (list_id, user_id) do nothing;
  else
    delete from public.list_editors where list_id = p_list and user_id = p_user;
  end if;
end;
$$;

create or replace function public.swifly_set_list_follow(p_list uuid, p_follow boolean)
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
  if not public.swifly_can_view_list(p_list) then
    raise exception 'This list is not available';
  end if;
  if exists (select 1 from public.lists where id = p_list and owner_id = me) then
    raise exception 'You own this list';
  end if;

  if coalesce(p_follow, false) then
    insert into public.list_follows (list_id, user_id)
    values (p_list, me)
    on conflict (list_id, user_id) do nothing;
  else
    delete from public.list_follows where list_id = p_list and user_id = me;
    -- Unfollowing also unpins it.
    delete from public.list_pins where list_id = p_list and user_id = me;
  end if;
end;
$$;

create or replace function public.swifly_set_list_pin(p_list uuid, p_pinned boolean)
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

  if not coalesce(p_pinned, false) then
    delete from public.list_pins where list_id = p_list and user_id = me;
    return;
  end if;

  if not public.swifly_can_view_list(p_list) then
    raise exception 'This list is not available';
  end if;
  if not (
    public.swifly_is_list_editor(p_list)
    or exists (select 1 from public.list_follows f where f.list_id = p_list and f.user_id = me)
  ) then
    raise exception 'Follow this list before you pin it';
  end if;
  if exists (select 1 from public.list_pins where list_id = p_list and user_id = me) then
    return;
  end if;
  if (select count(*) from public.list_pins where user_id = me) >= 5 then
    raise exception 'You can pin up to 5 lists';
  end if;

  insert into public.list_pins (user_id, list_id, position)
  values (
    me,
    p_list,
    coalesce((select max(position) + 1 from public.list_pins where user_id = me), 0)
  );
end;
$$;

-- Lock the function API: signed-in users only.
revoke all on function public.swifly_create_list(text, text, text, text, boolean) from public, anon;
revoke all on function public.swifly_update_list(uuid, text, text, text, text, boolean) from public, anon;
revoke all on function public.swifly_delete_list(uuid) from public, anon;
revoke all on function public.swifly_add_list_member(uuid, uuid) from public, anon;
revoke all on function public.swifly_remove_list_member(uuid, uuid) from public, anon;
revoke all on function public.swifly_set_list_editor(uuid, uuid, boolean) from public, anon;
revoke all on function public.swifly_set_list_follow(uuid, boolean) from public, anon;
revoke all on function public.swifly_set_list_pin(uuid, boolean) from public, anon;

grant execute on function public.swifly_create_list(text, text, text, text, boolean) to authenticated;
grant execute on function public.swifly_update_list(uuid, text, text, text, text, boolean) to authenticated;
grant execute on function public.swifly_delete_list(uuid) to authenticated;
grant execute on function public.swifly_add_list_member(uuid, uuid) to authenticated;
grant execute on function public.swifly_remove_list_member(uuid, uuid) to authenticated;
grant execute on function public.swifly_set_list_editor(uuid, uuid, boolean) to authenticated;
grant execute on function public.swifly_set_list_follow(uuid, boolean) to authenticated;
grant execute on function public.swifly_set_list_pin(uuid, boolean) to authenticated;

-- 5. Row Level Security ------------------------------------------------------

alter table public.lists         enable row level security;
alter table public.list_members  enable row level security;
alter table public.list_follows  enable row level security;
alter table public.list_editors  enable row level security;
alter table public.list_pins     enable row level security;

-- No direct writes from the app: every change goes through the functions above.
revoke all on public.lists, public.list_members, public.list_follows,
              public.list_editors, public.list_pins from anon, authenticated;
grant select on public.lists, public.list_members, public.list_follows,
                public.list_editors, public.list_pins to authenticated;

drop policy if exists swifly_lists_select on public.lists;
create policy swifly_lists_select on public.lists
  for select to authenticated
  using (public.swifly_can_view_list(id));

drop policy if exists swifly_list_members_select on public.list_members;
create policy swifly_list_members_select on public.list_members
  for select to authenticated
  using (public.swifly_can_view_list(list_id));

drop policy if exists swifly_list_follows_select on public.list_follows;
create policy swifly_list_follows_select on public.list_follows
  for select to authenticated
  using (user_id = auth.uid() or public.swifly_is_list_owner(list_id));

drop policy if exists swifly_list_editors_select on public.list_editors;
create policy swifly_list_editors_select on public.list_editors
  for select to authenticated
  using (public.swifly_can_view_list(list_id));

drop policy if exists swifly_list_pins_select on public.list_pins;
create policy swifly_list_pins_select on public.list_pins
  for select to authenticated
  using (user_id = auth.uid());




