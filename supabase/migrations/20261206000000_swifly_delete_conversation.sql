-- Swifly: delete a direct conversation.
-- Each person hides the conversation for themselves. When BOTH people have
-- hidden a message, the message (and its reactions and hidden rows) is
-- removed from the database. Messages that have been reported are kept so
-- moderation evidence is not lost.
-- Run in Supabase Dashboard -> SQL Editor.

create or replace function public.swifs_delete_conversation(other_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  removed integer := 0;
begin
  if me is null then
    raise exception 'Not signed in';
  end if;
  if other_id is null or other_id = me then
    raise exception 'Invalid conversation';
  end if;

  -- 1. Hide every direct message in this conversation for the caller.
  insert into public.message_hidden (message_id, user_id, created_at)
  select m.id, me, now()
  from public.messages m
  where m.group_id is null
    and ((m.sender = me and m.recipient = other_id)
      or (m.sender = other_id and m.recipient = me))
  on conflict (message_id, user_id) do nothing;

  -- 2. Collect messages that both people have now hidden.
  create temporary table if not exists swifs_gone_messages (id uuid) on commit drop;
  truncate swifs_gone_messages;

  insert into swifs_gone_messages (id)
  select m.id
  from public.messages m
  where m.group_id is null
    and ((m.sender = me and m.recipient = other_id)
      or (m.sender = other_id and m.recipient = me))
    and exists (select 1 from public.message_hidden h
                where h.message_id = m.id and h.user_id = m.sender)
    and exists (select 1 from public.message_hidden h
                where h.message_id = m.id and h.user_id = m.recipient)
    and not exists (select 1 from public.message_reports r
                    where r.message_id = m.id);

  -- 3. Remove them for real.
  delete from public.message_reactions
  where message_id in (select id from swifs_gone_messages);

  delete from public.message_hidden
  where message_id in (select id from swifs_gone_messages);

  delete from public.messages
  where id in (select id from swifs_gone_messages);

  get diagnostics removed = row_count;
  return removed;
end;
$$;

revoke all on function public.swifs_delete_conversation(uuid) from public;
grant execute on function public.swifs_delete_conversation(uuid) to authenticated;
