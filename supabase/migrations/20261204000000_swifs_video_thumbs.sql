-- Swifs: every video post and story stores a still image (its thumbnail)
-- so the feed shows a picture instantly before the video starts.
-- Run after 20261203000000_swifs_post_video.sql. Safe to run more than once.

alter table public.post_media add column if not exists thumbnail_url text;
alter table public.stories add column if not exists thumbnail_url text;

drop function if exists public.swifs_create_post(text, text, text[], text, uuid, text);

create or replace function public.swifs_create_post(
  p_text text,
  p_audience text default 'everyone',
  p_tags text[] default '{}',
  p_image_url text default null,
  p_list_id uuid default null,
  p_media_kind text default 'image',
  p_thumbnail_url text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  new_id uuid;
  kind text := lower(coalesce(p_media_kind, 'image'));
begin
  if me is null then
    raise exception 'You are not signed in';
  end if;
  if p_text is null or length(trim(p_text)) = 0 then
    raise exception 'Write something before posting';
  end if;
  if length(p_text) > 280 then
    raise exception 'Posts can be at most 280 characters';
  end if;
  if kind not in ('image', 'video') then
    raise exception 'Unsupported media type: %', kind;
  end if;

  insert into public.posts (author_id, text, audience, tagged_handles)
  values (me, p_text, coalesce(p_audience, 'everyone'), coalesce(p_tags, '{}'))
  returning id into new_id;

  if p_image_url is not null and length(p_image_url) > 0 then
    insert into public.post_media (post_id, position, kind, storage_path, thumbnail_url)
    values (new_id, 0, kind, p_image_url, nullif(p_thumbnail_url, ''));
  end if;

  if p_list_id is not null then
    perform public.swifly_tag_post_to_list(new_id, p_list_id);
  end if;

  return new_id;
end;
$$;

revoke all on function public.swifs_create_post(text, text, text[], text, uuid, text, text)
  from public, anon;
grant execute on function public.swifs_create_post(text, text, text[], text, uuid, text, text)
  to authenticated;
