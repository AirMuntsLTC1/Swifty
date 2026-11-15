-- Swifly: create a post, media and optional list attachment atomically.
-- Apply after 20261125000000_swifly_list_social.sql.
-- The list link is written by the same transaction as the post so a failed
-- membership check cannot leave behind an untagged post that looked successful.

drop function if exists public.swifs_create_post(text, text, text[], text);

create or replace function public.swifs_create_post(
  p_text text,
  p_audience text default 'everyone',
  p_tags text[] default '{}',
  p_image_url text default null,
  p_list_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  new_id uuid;
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

  insert into public.posts (author_id, text, audience, tagged_handles)
  values (me, p_text, coalesce(p_audience, 'everyone'), coalesce(p_tags, '{}'))
  returning id into new_id;

  if p_image_url is not null and length(p_image_url) > 0 then
    insert into public.post_media (post_id, position, kind, storage_path)
    values (new_id, 0, 'image', p_image_url);
  end if;

  -- This SECURITY DEFINER function validates ownership/membership and creates
  -- list_post notifications. Any access error rolls this whole transaction back.
  if p_list_id is not null then
    perform public.swifly_tag_post_to_list(new_id, p_list_id);
  end if;

  return new_id;
end;
$$;

revoke all on function public.swifs_create_post(text, text, text[], text, uuid)
  from public, anon;
grant execute on function public.swifs_create_post(text, text, text[], text, uuid)
  to authenticated;




