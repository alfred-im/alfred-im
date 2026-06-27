-- Inbox = sola query su messages. Nessuna tabella inbox_threads, nessun thread_id.

-- ---------------------------------------------------------------------------
-- sync_cursors: peer al posto di inbox_thread_id (bridge futuro)
-- ---------------------------------------------------------------------------

alter table public.sync_cursors
  drop constraint if exists sync_cursors_owner_thread_protocol_key_unique;

alter table public.sync_cursors
  add column if not exists peer_profile_id uuid references public.profiles (id) on delete cascade;

update public.sync_cursors sc
set peer_profile_id = it.peer_profile_id
from public.inbox_threads it
where sc.inbox_thread_id = it.id
  and sc.peer_profile_id is null;

alter table public.sync_cursors
  drop column if exists inbox_thread_id;

alter table public.sync_cursors
  add constraint sync_cursors_owner_peer_protocol_key_unique
  unique (profile_id, peer_profile_id, protocol, cursor_key);

-- ---------------------------------------------------------------------------
-- Trigger messaggio: solo delivered / outbox (niente inbox_threads)
-- ---------------------------------------------------------------------------

drop trigger if exists messages_after_insert on public.messages;

create or replace function public.on_message_inserted()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.protocol = 'internal' then
    update public.messages
    set delivery_status = 'delivered'
    where id = new.id
      and delivery_status = 'sent';
  elsif new.protocol in ('xmpp', 'matrix') then
    update public.messages
    set delivery_status = 'pending'
    where id = new.id;

    insert into public.outbox (message_id, protocol, payload)
    values (
      new.id,
      new.protocol,
      jsonb_build_object(
        'body', new.body,
        'content_type', new.content_type,
        'media_url', new.media_url,
        'media_mime', new.media_mime,
        'media_size_bytes', new.media_size_bytes,
        'duration_seconds', new.duration_seconds,
        'sender_id', new.sender_id,
        'recipient_external_address', new.recipient_external_address,
        'client_message_id', new.client_message_id
      )
    );
  end if;

  return new;
end;
$$;

create trigger messages_after_insert
  after insert on public.messages
  for each row execute function public.on_message_inserted();

-- ---------------------------------------------------------------------------
-- RPC: inbox derivata da messages (GROUP BY controparte)
-- ---------------------------------------------------------------------------

drop function if exists public.list_inbox();

create or replace function public.list_inbox()
returns table (
  protocol public.contact_protocol,
  display_name text,
  peer_profile_id uuid,
  peer_external_address text,
  last_message_preview text,
  last_message_at timestamptz,
  unread_count integer
)
language sql
stable
security definer
set search_path = public
as $$
  with me as (
    select auth.uid() as uid
  ),
  direct as (
    select
      m.protocol,
      case
        when m.sender_id = me.uid then m.recipient_profile_id
        else m.sender_id
      end as peer_profile_id,
      m.recipient_external_address as peer_external_address,
      m.created_at,
      m.sender_id,
      m.recipient_profile_id,
      m.content_type,
      m.body,
      m.duration_seconds,
      m.delivery_status
    from public.messages m
    cross join me
    where me.uid is not null
      and m.protocol = 'internal'
      and m.recipient_profile_id is not null
      and (m.sender_id = me.uid or m.recipient_profile_id = me.uid)
      and m.marker_type is null
      and (
        trim(m.body) <> ''
        or m.content_type in ('gif', 'voice')
      )
  ),
  latest as (
    select distinct on (d.peer_profile_id)
      d.protocol,
      d.peer_profile_id,
      d.peer_external_address,
      d.created_at as last_message_at,
      d.content_type,
      d.body,
      d.duration_seconds
    from direct d
    order by d.peer_profile_id, d.created_at desc
  ),
  unread as (
    select
      d.peer_profile_id,
      count(*)::integer as unread_count
    from direct d
    cross join me
    where d.recipient_profile_id = me.uid
      and d.delivery_status not in ('read')
    group by d.peer_profile_id
  )
  select
    l.protocol,
    coalesce(nullif(trim(p.display_name), ''), 'Contatto') as display_name,
    l.peer_profile_id,
    l.peer_external_address,
    case
      when l.content_type = 'gif' then '[GIF]'
      when l.content_type = 'voice' then public.format_voice_preview(coalesce(l.duration_seconds, 0))
      else left(trim(l.body), 120)
    end as last_message_preview,
    l.last_message_at,
    coalesce(u.unread_count, 0) as unread_count
  from latest l
  left join public.profiles p on p.id = l.peer_profile_id
  left join unread u on u.peer_profile_id = l.peer_profile_id
  order by l.last_message_at desc nulls last;
$$;

-- ---------------------------------------------------------------------------
-- RPC: storico messaggi con un account (peer)
-- ---------------------------------------------------------------------------

create or replace function public.list_peer_messages(
  p_peer_profile_id uuid,
  p_limit integer default 100
)
returns setof public.messages
language sql
stable
security definer
set search_path = public
as $$
  select m.*
  from public.messages m
  where auth.uid() is not null
    and p_peer_profile_id is not null
    and m.marker_type is null
    and (
      trim(m.body) <> ''
      or m.content_type in ('gif', 'voice')
    )
    and (
      (m.sender_id = auth.uid() and m.recipient_profile_id = p_peer_profile_id)
      or (m.sender_id = p_peer_profile_id and m.recipient_profile_id = auth.uid())
    )
  order by m.created_at asc
  limit greatest(1, least(coalesce(p_limit, 100), 500));
$$;

-- ---------------------------------------------------------------------------
-- RPC: segna messaggi da peer come letti
-- ---------------------------------------------------------------------------

create or replace function public.mark_peer_read(p_peer_profile_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then
    raise exception 'not authenticated';
  end if;

  if p_peer_profile_id is null then
    raise exception 'peer required';
  end if;

  insert into public.message_read_receipts (message_id, profile_id, status)
  select m.id, v_me, 'read'::public.message_delivery_status
  from public.messages m
  where m.sender_id = p_peer_profile_id
    and m.recipient_profile_id = v_me
    and m.marker_type is null
    and (
      trim(m.body) <> ''
      or m.content_type in ('gif', 'voice')
    )
  on conflict do nothing;

  update public.messages m
  set delivery_status = 'read'
  where m.sender_id = p_peer_profile_id
    and m.recipient_profile_id = v_me
    and m.delivery_status in ('sent', 'delivered');
end;
$$;

-- ---------------------------------------------------------------------------
-- Revoca RPC obsolete + drop inbox_threads
-- ---------------------------------------------------------------------------

drop function if exists public.list_thread_messages(uuid, integer);
drop function if exists public.mark_thread_read(uuid);
drop function if exists public.upsert_inbox_thread(uuid, uuid, text, text, public.contact_protocol, text, uuid, timestamptz);

revoke all on function public.list_thread_messages(uuid, integer) from authenticated;
revoke all on function public.mark_thread_read(uuid) from authenticated;

grant execute on function public.list_inbox() to authenticated;
grant execute on function public.list_peer_messages(uuid, integer) to authenticated;
grant execute on function public.mark_peer_read(uuid) to authenticated;

revoke all on function public.list_peer_messages(uuid, integer) from anon;
revoke all on function public.mark_peer_read(uuid) from anon;

do $$
begin
  alter publication supabase_realtime drop table public.inbox_threads;
exception
  when others then null;
end $$;

drop policy if exists inbox_threads_select_own on public.inbox_threads;
drop policy if exists inbox_threads_update_own on public.inbox_threads;

drop table if exists public.inbox_threads cascade;
