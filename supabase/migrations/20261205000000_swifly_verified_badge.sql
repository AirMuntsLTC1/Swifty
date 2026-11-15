-- Swifly verified badge: real column, protected from self-verification.
-- Run in Supabase Dashboard -> SQL Editor (runs as postgres, so the admin
-- block at the bottom is allowed).

alter table public.profiles
  add column if not exists is_verified boolean not null default false;

alter table public.profiles
  add column if not exists verified_at timestamptz;

-- Only the Swifly team (SQL Editor / service role) can grant or remove the badge.
-- Users can still edit their own profile, but is_verified is ignored on insert
-- and any change to it from the app is rejected.
create or replace function public.swifs_guard_verified()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(auth.role(), '') = 'service_role'
     or current_user in ('postgres', 'supabase_admin') then
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.is_verified := false;
    new.verified_at := null;
  elsif new.is_verified is distinct from old.is_verified then
    raise exception 'Only the Swifly team can change verified status';
  end if;

  return new;
end;
$$;

drop trigger if exists swifs_guard_verified on public.profiles;
create trigger swifs_guard_verified
  before insert or update on public.profiles
  for each row execute function public.swifs_guard_verified();

-- Grant the badge to the owner account (wilmeolid@gmail.com, username maximo_db).
-- If the account has not been created yet, this prints a notice; sign in once
-- and run this block again.
do $$
declare
  uid uuid;
begin
  select id into uid
  from auth.users
  where lower(email) = 'wilmeolid@gmail.com'
  limit 1;

  if uid is null then
    raise notice 'No auth user for wilmeolid@gmail.com yet. Sign in once, then run this block again.';
    return;
  end if;

  update public.profiles
  set is_verified = true,
      verified_at = now()
  where id = uid;

  raise notice 'Verified badge granted to %', uid;
end $$;
