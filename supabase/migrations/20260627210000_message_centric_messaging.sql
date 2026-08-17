-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- Messaggistica centrata sui messaggi: elimina conversazioni come entità di dominio.
-- Inbox = inbox_threads (vista per utente + controparte); messaggi con sender/recipient.

-- ---------------------------------------------------------------------------
-- inbox_threads: raggruppamento inbox per utente (solo dopo il primo messaggio)
-- ---------------------------------------------------------------------------

create table public.inbox_threads (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  peer_profile_id uuid references public.profiles (id) on delete set null,
  peer_external_address text,
  peer_display_name text,
  protocol public.contact_protocol not null default 'internal',
  last_message_at timestamptz,
  last_message_preview text,
  last_message_sender_id uuid references public.profiles (id) on delete set null,
  unread_count integer not null default 0,
  last_read_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint inbox_threads_internal_peer check (
    protocol <> 'internal'
    or peer_profile_id is not null
  ),
  constraint inbox_threads_external_peer check (
    protocol = 'internal'
    or peer_external_address is not null
  )
);

create unique index inbox_threads_owner_peer_profile_idx
  on public.inbox_threads (owner_id, peer_profile_id)
  where peer_profile_id is not null;

create unique index inbox_threads_owner_external_idx
  on public.inbox_threads (owner_id, lower(peer_external_address))
  where peer_external_address is not null;

create index inbox_threads_owner_last_message_idx
  on public.inbox_threads (owner_id, last_message_at desc nulls last);

-- ---------------------------------------------------------------------------
-- messages: destinatario esplicito (niente conversation_id)
-- ---------------------------------------------------------------------------

alter table public.messages
  add column recipient_profile_id uuid references public.profiles (id),
  add column recipient_external_address text,
  add column protocol public.contact_protocol;

-- Migra dati esistenti prima di vincoli/drop
with message_migration as (
  select
    m.id as message_id,
    c.protocol,
    peer.peer_profile_id,
    peer.peer_external_address
  from public.messages m
  inner join public.conversations c on c.id = m.conversation_id
  left join lateral (
    select
      case when op.profile_id is distinct from m.sender_id then op.profile_id end as peer_profile_id,
      ct.external_address as peer_external_address
    from public.conversation_participants op
    left join public.contacts ct on ct.id = op.contact_id
    where op.conversation_id = m.conversation_id
      and (op.profile_id is distinct from m.sender_id or op.contact_id is not null)
    limit 1
  ) peer on true
)
update public.messages m
set
  protocol = mm.protocol,
  recipient_profile_id = mm.peer_profile_id,
  recipient_external_address = mm.peer_external_address
from message_migration mm
where m.id = mm.message_id;

insert into public.inbox_threads (
  owner_id,
  peer_profile_id,
  peer_external_address,
  peer_display_name,
  protocol,
  last_message_at,
  last_message_preview,
  last_message_sender_id,
  unread_count,
  last_read_at
)
select
  cp.profile_id as owner_id,
  case when peer_op.profile_id is distinct from cp.profile_id then peer_op.profile_id end,
  ct.external_address,
  coalesce(
    nullif(trim(peer_p.display_name), ''),
    nullif(trim(ct.display_name), ''),
    nullif(trim(c.title), ''),
    'Contatto'
  ),
  c.protocol,
  c.last_message_at,
  c.last_message_preview,
  c.last_message_sender_id,
  cp.unread_count,
  cp.last_read_at
from public.conversation_participants cp
inner join public.conversations c on c.id = cp.conversation_id
left join lateral (
  select op.profile_id, op.contact_id
  from public.conversation_participants op
  where op.conversation_id = c.id
    and op.profile_id is distinct from cp.profile_id
  limit 1
) peer_op on true
left join public.profiles peer_p on peer_p.id = peer_op.profile_id
left join public.contacts ct on ct.id = peer_op.contact_id
where c.last_message_at is not null;

-- outbox: non dipende più da conversation_id
alter table public.outbox drop column conversation_id;

-- sync_cursors: thread inbox al posto di conversation
alter table public.sync_cursors
  add column inbox_thread_id uuid references public.inbox_threads (id) on delete cascade;

update public.sync_cursors sc
set inbox_thread_id = it.id
from public.conversation_participants cp
left join public.conversation_participants cp_peer
  on cp_peer.conversation_id = cp.conversation_id
  and cp_peer.profile_id <> cp.profile_id
inner join public.inbox_threads it
  on it.owner_id = cp.profile_id
  and (
    (it.peer_profile_id is not null and it.peer_profile_id = cp_peer.profile_id)
    or (
      it.peer_external_address is not null
      and cp_peer.contact_id is not null
      and lower(it.peer_external_address) = lower(
        (select c2.external_address from public.contacts c2 where c2.id = cp_peer.contact_id)
      )
    )
  )
where sc.conversation_id = cp.conversation_id
  and sc.profile_id = cp.profile_id;

alter table public.sync_cursors drop column conversation_id;

alter table public.sync_cursors
  drop constraint if exists sync_cursors_profile_id_conversation_id_protocol_cursor_key_key;

alter table public.sync_cursors
  add constraint sync_cursors_owner_thread_protocol_key_unique
  unique (profile_id, inbox_thread_id, protocol, cursor_key);

-- Rimuovi modello conversazione (policy prima delle dipendenze)
drop policy if exists messages_select_participant on public.messages;
drop policy if exists messages_insert_participant on public.messages;
drop policy if exists receipts_select_participant on public.message_read_receipts;
drop policy if exists conversations_select_participant on public.conversations;
drop policy if exists participants_select_own_or_shared on public.conversation_participants;
drop policy if exists participants_update_own on public.conversation_participants;

alter table public.messages drop constraint if exists messages_conversation_id_client_message_id_key;
alter table public.messages drop constraint if exists messages_conversation_id_fkey;
alter table public.messages drop column conversation_id;

alter table public.messages
  alter column protocol set default 'internal';

update public.messages
set protocol = 'internal'
where protocol is null;

alter table public.messages
  alter column protocol set not null;

create unique index messages_sender_client_id_idx
  on public.messages (sender_id, client_message_id)
  where client_message_id is not null;

create index messages_direct_pair_idx
  on public.messages (sender_id, recipient_profile_id, created_at);

create index messages_recipient_pair_idx
  on public.messages (recipient_profile_id, sender_id, created_at);

drop trigger if exists messages_after_insert on public.messages;
drop function if exists public.is_conversation_participant(uuid);

drop table if exists public.conversation_participants cascade;
drop table if exists public.conversations cascade;

-- ---------------------------------------------------------------------------
-- Helper: partecipazione messaggio 1:1
-- ---------------------------------------------------------------------------

create or replace function public.is_message_party(p_message_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.messages m
    where m.id = p_message_id
      and (
        m.sender_id = auth.uid()
        or m.recipient_profile_id = auth.uid()
      )
  );
$$;

create or replace function public.is_direct_message_visible(
  p_sender_id uuid,
  p_recipient_profile_id uuid,
  p_owner_id uuid,
  p_peer_profile_id uuid
)
returns boolean
language sql
immutable
as $$
  select
    p_sender_id = p_owner_id
    and p_recipient_profile_id = p_peer_profile_id
    or p_sender_id = p_peer_profile_id
    and p_recipient_profile_id = p_owner_id;
$$;

-- ---------------------------------------------------------------------------
-- Helper: upsert thread inbox (solo al primo messaggio o aggiornamento)
-- ---------------------------------------------------------------------------

create or replace function public.upsert_inbox_thread(
  p_owner_id uuid,
  p_peer_profile_id uuid,
  p_peer_external_address text,
  p_peer_display_name text,
  p_protocol public.contact_protocol,
  p_preview text,
  p_sender_id uuid,
  p_at timestamptz
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_thread_id uuid;
begin
  if p_protocol = 'internal' then
    insert into public.inbox_threads (
      owner_id,
      peer_profile_id,
      peer_display_name,
      protocol,
      last_message_at,
      last_message_preview,
      last_message_sender_id,
      unread_count
    )
    values (
      p_owner_id,
      p_peer_profile_id,
      p_peer_display_name,
      p_protocol,
      p_at,
      p_preview,
      p_sender_id,
      case when p_sender_id = p_owner_id then 0 else 1 end
    )
    on conflict (owner_id, peer_profile_id) where peer_profile_id is not null
    do update set
      peer_display_name = coalesce(excluded.peer_display_name, inbox_threads.peer_display_name),
      last_message_at = excluded.last_message_at,
      last_message_preview = excluded.last_message_preview,
      last_message_sender_id = excluded.last_message_sender_id,
      unread_count = case
        when excluded.last_message_sender_id = inbox_threads.owner_id then inbox_threads.unread_count
        else inbox_threads.unread_count + 1
      end,
      updated_at = now()
    returning id into v_thread_id;
  else
    select t.id into v_thread_id
    from public.inbox_threads t
    where t.owner_id = p_owner_id
      and t.peer_external_address is not null
      and lower(t.peer_external_address) = lower(p_peer_external_address)
    limit 1;

    if v_thread_id is null then
      insert into public.inbox_threads (
        owner_id,
        peer_external_address,
        peer_display_name,
        protocol,
        last_message_at,
        last_message_preview,
        last_message_sender_id,
        unread_count
      )
      values (
        p_owner_id,
        p_peer_external_address,
        p_peer_display_name,
        p_protocol,
        p_at,
        p_preview,
        p_sender_id,
        case when p_sender_id = p_owner_id then 0 else 1 end
      )
      returning id into v_thread_id;
    else
      update public.inbox_threads
      set
        peer_display_name = coalesce(p_peer_display_name, peer_display_name),
        last_message_at = p_at,
        last_message_preview = p_preview,
        last_message_sender_id = p_sender_id,
        unread_count = case
          when p_sender_id = owner_id then unread_count
          else unread_count + 1
        end,
        updated_at = now()
      where id = v_thread_id;
    end if;
  end if;

  return v_thread_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Trigger: messaggio inserito → thread inbox, delivered/outbox
-- ---------------------------------------------------------------------------

create or replace function public.on_message_inserted()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_preview text;
  v_peer_display_name text;
begin
  if new.content_type = 'gif' then
    v_preview := '[GIF]';
  elsif new.content_type = 'voice' then
    v_preview := public.format_voice_preview(coalesce(new.duration_seconds, 0));
  else
    v_preview := left(trim(new.body), 120);
    if v_preview = '' and new.marker_type is not null then
      v_preview := '[stato messaggio]';
    end if;
  end if;

  if new.protocol = 'internal' and new.recipient_profile_id is not null then
    select coalesce(p.display_name, new.recipient_profile_id::text)
    into v_peer_display_name
    from public.profiles p
    where p.id = new.recipient_profile_id;

    perform public.upsert_inbox_thread(
      new.sender_id,
      new.recipient_profile_id,
      null,
      v_peer_display_name,
      new.protocol,
      v_preview,
      new.sender_id,
      new.created_at
    );

    select coalesce(p.display_name, new.sender_id::text)
    into v_peer_display_name
    from public.profiles p
    where p.id = new.sender_id;

    perform public.upsert_inbox_thread(
      new.recipient_profile_id,
      new.sender_id,
      null,
      v_peer_display_name,
      new.protocol,
      v_preview,
      new.sender_id,
      new.created_at
    );
  elsif new.protocol in ('xmpp', 'matrix') then
    perform public.upsert_inbox_thread(
      new.sender_id,
      null,
      new.recipient_external_address,
      coalesce(new.recipient_external_address, 'Contatto'),
      new.protocol,
      v_preview,
      new.sender_id,
      new.created_at
    );
  end if;

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
-- RPC: inbox (solo thread con messaggi)
-- ---------------------------------------------------------------------------

create or replace function public.list_inbox()
returns table (
  thread_id uuid,
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
  select
    t.id as thread_id,
    t.protocol,
    coalesce(
      nullif(trim(p.display_name), ''),
      nullif(trim(t.peer_display_name), ''),
      nullif(trim(t.peer_external_address), ''),
      'Contatto'
    ) as display_name,
    t.peer_profile_id,
    t.peer_external_address,
    coalesce(t.last_message_preview, '') as last_message_preview,
    t.last_message_at,
    t.unread_count
  from public.inbox_threads t
  left join public.profiles p on p.id = t.peer_profile_id
  where t.owner_id = auth.uid()
    and t.last_message_at is not null
  order by t.last_message_at desc nulls last;
$$;

-- ---------------------------------------------------------------------------
-- RPC: messaggi di un thread inbox
-- ---------------------------------------------------------------------------

create or replace function public.list_thread_messages(
  p_thread_id uuid,
  p_limit integer default 100
)
returns setof public.messages
language sql
stable
security definer
set search_path = public
as $$
  select m.*
  from public.inbox_threads t
  inner join public.messages m on public.is_direct_message_visible(
    m.sender_id,
    m.recipient_profile_id,
    t.owner_id,
    t.peer_profile_id
  )
  where t.id = p_thread_id
    and t.owner_id = auth.uid()
    and m.marker_type is null
    and (
      trim(m.body) <> ''
      or m.content_type in ('gif', 'voice')
    )
  order by m.created_at asc
  limit greatest(1, least(coalesce(p_limit, 100), 500));
$$;

-- ---------------------------------------------------------------------------
-- RPC: segna thread come letto
-- ---------------------------------------------------------------------------

create or replace function public.mark_thread_read(p_thread_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_thread public.inbox_threads%rowtype;
begin
  if v_me is null then
    raise exception 'not authenticated';
  end if;

  select * into v_thread
  from public.inbox_threads
  where id = p_thread_id and owner_id = v_me;

  if not found then
    raise exception 'thread not found';
  end if;

  update public.inbox_threads
  set unread_count = 0, last_read_at = now(), updated_at = now()
  where id = p_thread_id and owner_id = v_me;

  insert into public.message_read_receipts (message_id, profile_id, status)
  select m.id, v_me, 'read'::public.message_delivery_status
  from public.messages m
  where public.is_direct_message_visible(
      m.sender_id,
      m.recipient_profile_id,
      v_thread.owner_id,
      v_thread.peer_profile_id
    )
    and m.sender_id <> v_me
    and m.marker_type is null
    and (
      trim(m.body) <> ''
      or m.content_type in ('gif', 'voice')
    )
  on conflict do nothing;

  update public.messages m
  set delivery_status = 'read'
  from public.inbox_threads t
  where t.id = p_thread_id
    and t.owner_id = v_me
    and public.is_direct_message_visible(
      m.sender_id,
      m.recipient_profile_id,
      t.owner_id,
      t.peer_profile_id
    )
    and m.sender_id = v_me
    and t.last_read_at is not null
    and m.created_at <= t.last_read_at
    and m.delivery_status in ('sent', 'delivered');
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: invio messaggio a profilo Alfred (nessuna conversazione esposta)
-- ---------------------------------------------------------------------------

create or replace function public.send_message_to_profile(
  p_recipient_profile_id uuid,
  p_body text default '',
  p_client_message_id text default null,
  p_content_type public.message_content_type default 'text',
  p_media_url text default null,
  p_duration_seconds integer default null,
  p_media_mime text default null,
  p_media_size_bytes bigint default null
)
returns public.messages
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_id uuid;
  v_row public.messages;
  v_body text := coalesce(p_body, '');
  v_media_url text := nullif(trim(coalesce(p_media_url, '')), '');
  v_media_mime text := nullif(trim(coalesce(p_media_mime, '')), '');
begin
  if v_me is null then
    raise exception 'not authenticated';
  end if;

  if p_recipient_profile_id is null then
    raise exception 'recipient required';
  end if;

  if p_recipient_profile_id = v_me then
    raise exception 'cannot message yourself';
  end if;

  if not exists (select 1 from public.profiles where id = p_recipient_profile_id) then
    raise exception 'recipient not found';
  end if;

  if p_content_type = 'text' then
    if length(trim(v_body)) = 0 then
      raise exception 'empty message';
    end if;
  elsif p_content_type = 'gif' then
    if v_media_url is null then
      raise exception 'gif requires media_url';
    end if;
  elsif p_content_type = 'voice' then
    if v_media_url is null then
      raise exception 'voice requires media_url';
    end if;
    if p_duration_seconds is null or p_duration_seconds <= 0 then
      raise exception 'voice requires duration_seconds';
    end if;
    if v_media_mime is null then
      raise exception 'voice requires media_mime';
    end if;
    if p_media_size_bytes is not null and p_media_size_bytes <= 0 then
      raise exception 'invalid media_size_bytes';
    end if;
  else
    raise exception 'unsupported content_type';
  end if;

  insert into public.messages (
    sender_id,
    recipient_profile_id,
    protocol,
    body,
    client_message_id,
    delivery_status,
    content_type,
    media_url,
    duration_seconds,
    media_mime,
    media_size_bytes
  )
  values (
    v_me,
    p_recipient_profile_id,
    'internal',
    trim(v_body),
    p_client_message_id,
    'sent',
    p_content_type,
    v_media_url,
    p_duration_seconds,
    v_media_mime,
    p_media_size_bytes
  )
  returning id into v_id;

  select * into v_row from public.messages where id = v_id;
  return v_row;
end;
$$;

-- Nota: non aggiungere un secondo overload (uuid,text,text) — PostgREST HTTP 300.
-- Vedi migrazione 20260627220000_fix_send_message_to_profile_overload.sql

-- ---------------------------------------------------------------------------
-- Revoca RPC conversazione (non più esposte al client)
-- ---------------------------------------------------------------------------

drop function if exists public.list_conversations();
drop function if exists public.get_or_create_direct_conversation(uuid);
drop function if exists public.get_or_create_conversation_from_contact(uuid);
drop function if exists public.mark_conversation_read(uuid);
drop function if exists public.send_message(uuid, text, text);
drop function if exists public.send_message(uuid, text, text, public.message_content_type, text);
drop function if exists public.send_message(uuid, text, text, public.message_content_type, text, integer, text, bigint);

revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function public.on_message_inserted() from public, anon, authenticated;
revoke all on function public.is_message_party(uuid) from public, anon;
revoke all on function public.upsert_inbox_thread(uuid, uuid, text, text, public.contact_protocol, text, uuid, timestamptz) from public, anon, authenticated;

grant execute on function public.list_inbox() to authenticated;
grant execute on function public.list_thread_messages(uuid, integer) to authenticated;
grant execute on function public.mark_thread_read(uuid) to authenticated;
grant execute on function public.send_message_to_profile(uuid, text, text, public.message_content_type, text, integer, text, bigint) to authenticated;

revoke all on function public.list_inbox() from anon;
revoke all on function public.list_thread_messages(uuid, integer) from anon;
revoke all on function public.mark_thread_read(uuid) from anon;
revoke all on function public.send_message_to_profile(uuid, text, text, public.message_content_type, text, integer, text, bigint) from anon;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.inbox_threads enable row level security;

create policy inbox_threads_select_own
  on public.inbox_threads for select to authenticated
  using (owner_id = auth.uid());

create policy inbox_threads_update_own
  on public.inbox_threads for update to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy messages_select_party
  on public.messages for select to authenticated
  using (
    sender_id = auth.uid()
    or recipient_profile_id = auth.uid()
  );

create policy messages_insert_sender
  on public.messages for insert to authenticated
  with check (
    sender_id = auth.uid()
    and (
      recipient_profile_id is not null
      or recipient_external_address is not null
    )
  );

drop policy if exists receipts_select_participant on public.message_read_receipts;

create policy receipts_select_party
  on public.message_read_receipts for select to authenticated
  using (public.is_message_party(message_id));

-- Realtime
do $$
begin
  alter publication supabase_realtime drop table public.conversations;
exception
  when undefined_table then null;
  when others then null;
end $$;

do $$
begin
  alter publication supabase_realtime drop table public.conversation_participants;
exception
  when undefined_table then null;
  when others then null;
end $$;

alter publication supabase_realtime add table public.inbox_threads;
