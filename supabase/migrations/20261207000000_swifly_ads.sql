-- Swifly ads: campaigns shown in the home feed, with impression, click and
-- hide tracking. Campaigns are created by the Swifly team (SQL Editor) only.
-- Run in Supabase Dashboard -> SQL Editor.

create table if not exists public.ad_campaigns (
  id uuid primary key default gen_random_uuid(),
  advertiser_name text not null,
  advertiser_handle text not null,
  advertiser_avatar_url text,
  advertiser_verified boolean not null default false,
  headline text not null,
  body text,
  image_url text,
  cta_label text not null default 'Learn more',
  cta_url text not null,
  status text not null default 'paused'
    check (status in ('active', 'paused', 'ended')),
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.ad_events (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.ad_campaigns(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  kind text not null check (kind in ('impression', 'click')),
  created_at timestamptz not null default now()
);

create table if not exists public.ad_hidden (
  user_id uuid not null references auth.users(id) on delete cascade,
  campaign_id uuid not null references public.ad_campaigns(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, campaign_id)
);

alter table public.ad_campaigns enable row level security;
alter table public.ad_events enable row level security;
alter table public.ad_hidden enable row level security;

-- Users can read only campaigns that are active right now.
-- Nobody can insert, update or delete campaigns from the app.
drop policy if exists ad_campaigns_read_active on public.ad_campaigns;
create policy ad_campaigns_read_active on public.ad_campaigns
  for select to authenticated
  using (
    status = 'active'
    and starts_at <= now()
    and (ends_at is null or ends_at > now())
  );

-- Ad events and hidden ads are written only through the functions below.
-- Users cannot read other people's events.

-- Active ads this user has not hidden, in random order.
create or replace function public.swifs_active_ads(lim integer default 10)
returns setof public.ad_campaigns
language sql
stable
security definer
set search_path = public
as $$
  select c.*
  from public.ad_campaigns c
  where c.status = 'active'
    and c.starts_at <= now()
    and (c.ends_at is null or c.ends_at > now())
    and not exists (
      select 1 from public.ad_hidden h
      where h.campaign_id = c.id and h.user_id = auth.uid()
    )
  order by random()
  limit greatest(1, least(coalesce(lim, 10), 20));
$$;

-- Record an impression or click, or hide an ad for the signed-in user.
create or replace function public.swifs_record_ad_event(campaign uuid, kind text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'Not signed in';
  end if;
  if kind not in ('impression', 'click', 'hide') then
    raise exception 'Invalid ad event';
  end if;
  if not exists (select 1 from public.ad_campaigns c where c.id = campaign) then
    raise exception 'Unknown ad';
  end if;

  if kind = 'hide' then
    insert into public.ad_hidden (user_id, campaign_id)
    values (me, campaign)
    on conflict (user_id, campaign_id) do nothing;
  else
    insert into public.ad_events (campaign_id, user_id, kind)
    values (campaign, me, kind);
  end if;
end;
$$;

revoke all on function public.swifs_active_ads(integer) from public;
revoke all on function public.swifs_record_ad_event(uuid, text) from public;
grant execute on function public.swifs_active_ads(integer) to authenticated;
grant execute on function public.swifs_record_ad_event(uuid, text) to authenticated;
