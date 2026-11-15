-- Swifly ads v2: image, card and video campaigns.
-- Run in Supabase Dashboard -> SQL Editor after 20261207000000_swifly_ads.sql.

alter table public.ad_campaigns
  add column if not exists format text not null default 'image';

alter table public.ad_campaigns
  add column if not exists video_url text;

alter table public.ad_campaigns
  drop constraint if exists ad_campaigns_format_check;

alter table public.ad_campaigns
  add constraint ad_campaigns_format_check
  check (format in ('image', 'card', 'video'));

alter table public.ad_campaigns
  drop constraint if exists ad_campaigns_video_needs_url;

alter table public.ad_campaigns
  add constraint ad_campaigns_video_needs_url
  check (format <> 'video' or video_url is not null);

-- swifs_active_ads (from v1) returns ad_campaigns rows, so the new columns
-- are included automatically.
