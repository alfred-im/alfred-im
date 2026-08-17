-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- Mailbox per-owner archive: drop message-centric shared rows, recreate messages.

-- ---------------------------------------------------------------------------
-- Teardown legacy message-centric
-- ---------------------------------------------------------------------------

drop trigger if exists messages_after_insert on public.messages;

drop function if exists public.on_message_inserted();

drop policy if exists messages_select_party on public.messages;
drop policy if exists messages_insert_sender on public.messages;
drop policy if exists messages_select_own on public.messages;
drop policy if exists messages_update_own on public.messages;

truncate table public.outbox;

drop table if exists public.message_read_receipts cascade;

drop table if exists public.messages cascade;

-- ---------------------------------------------------------------------------
-- messages (per-owner archive)
-- ---------------------------------------------------------------------------

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  peer_profile_id uuid references public.profiles (id) on delete set null,
  peer_external_address text,
  logical_message_id uuid not null,
  client_message_id text,
  protocol public.contact_protocol not null default 'internal',
  body text not null default '',
  content_type public.message_content_type not null default 'text',
  media_url text,
  duration_seconds integer,
  media_mime text,
  media_size_bytes bigint,
  latitude double precision,
  longitude double precision,
  delivered_at timestamptz,
  read_at timestamptz,
  failed_at timestamptz,
  external_id text,
  created_at timestamptz not null default now(),
  constraint messages_location_requires_coords check (
    content_type <> 'location'
    or (
      latitude is not null
      and longitude is not null
      and latitude >= -90
      and latitude <= 90
      and longitude >= -180
      and longitude <= 180
    )
  )
);

create unique index messages_owner_client_id_idx
  on public.messages (owner_id, client_message_id)
  where client_message_id is not null;

create unique index messages_owner_logical_id_idx
  on public.messages (owner_id, logical_message_id);

create index messages_owner_peer_created_idx
  on public.messages (owner_id, peer_profile_id, created_at);

create index messages_logical_message_id_idx
  on public.messages (logical_message_id);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.messages enable row level security;

create policy messages_select_own
  on public.messages for select to authenticated
  using (owner_id = auth.uid());

create policy messages_update_own
  on public.messages for update to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

-- Inserts via SECURITY DEFINER RPC only.

do $do$
begin
  alter publication supabase_realtime add table public.messages;
exception
  when duplicate_object then null;
  when others then null;
end $do$;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public.mailbox_has_renderable_content(
  p_body text,
  p_content_type public.message_content_type
)
returns boolean
language sql
immutable
as $$
  select
    trim(coalesce(p_body, '')) <> ''
    or p_content_type in ('gif', 'voice', 'location');
$$;

-- ---------------------------------------------------------------------------
-- RPC: send (outbox always + sync internal delivery)
-- ---------------------------------------------------------------------------

create or replace function public.send_message_to_profile(
  p_recipient_profile_id uuid,
  p_body text default '',
  p_client_message_id text default null,
  p_content_type public.message_content_type default 'text',
  p_media_url text default null,
  p_duration_seconds integer default null,
  p_media_mime text default null,
  p_media_size_bytes bigint default null,
  p_latitude double precision default null,
  p_longitude double precision default null
)
returns public.messages
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_lambda uuid;
  v_sender_id uuid;
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

  if p_client_message_id is not null then
    select m.id into v_sender_id
    from public.messages m
    where m.owner_id = v_me
      and m.client_message_id = p_client_message_id
    limit 1;

    if v_sender_id is not null then
      select * into v_row from public.messages where id = v_sender_id;
      return v_row;
    end if;
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
  elsif p_content_type = 'location' then
    if p_latitude is null or p_longitude is null then
      raise exception 'location requires latitude and longitude';
    end if;
    if p_latitude < -90 or p_latitude > 90 then
      raise exception 'invalid latitude';
    end if;
    if p_longitude < -180 or p_longitude > 180 then
      raise exception 'invalid longitude';
    end if;
  else
    raise exception 'unsupported content_type';
  end if;

  v_lambda := gen_random_uuid();

  insert into public.messages (
    owner_id,
    author_id,
    peer_profile_id,
    logical_message_id,
    client_message_id,
    protocol,
    body,
    content_type,
    media_url,
    duration_seconds,
    media_mime,
    media_size_bytes,
    latitude,
    longitude
  )
  values (
    v_me,
    v_me,
    p_recipient_profile_id,
    v_lambda,
    p_client_message_id,
    'internal',
    trim(v_body),
    p_content_type,
    v_media_url,
    p_duration_seconds,
    v_media_mime,
    p_media_size_bytes,
    p_latitude,
    p_longitude
  )
  returning id into v_sender_id;

  insert into public.outbox (message_id, protocol, payload, status)
  values (
    v_sender_id,
    'internal',
    jsonb_build_object(
      'logical_message_id', v_lambda,
      'sender_id', v_me,
      'recipient_profile_id', p_recipient_profile_id,
      'body', trim(v_body),
      'content_type', p_content_type,
      'media_url', v_media_url,
      'media_mime', v_media_mime,
      'media_size_bytes', p_media_size_bytes,
      'duration_seconds', p_duration_seconds,
      'latitude', p_latitude,
      'longitude', p_longitude,
      'client_message_id', p_client_message_id
    ),
    'queued'
  );

  insert into public.messages (
    owner_id,
    author_id,
    peer_profile_id,
    logical_message_id,
    protocol,
    body,
    content_type,
    media_url,
    duration_seconds,
    media_mime,
    media_size_bytes,
    latitude,
    longitude
  )
  values (
    p_recipient_profile_id,
    v_me,
    v_me,
    v_lambda,
    'internal',
    trim(v_body),
    p_content_type,
    v_media_url,
    p_duration_seconds,
    v_media_mime,
    p_media_size_bytes,
    p_latitude,
    p_longitude
  );

  update public.messages
  set delivered_at = now()
  where id = v_sender_id
    and delivered_at is null;

  update public.outbox
  set status = 'completed', updated_at = now()
  where message_id = v_sender_id
    and protocol = 'internal';

  select * into v_row from public.messages where id = v_sender_id;
  return v_row;
end;
$$;

revoke all on function public.send_message_to_profile(
  uuid, text, text, public.message_content_type, text, integer, text, bigint, double precision, double precision
) from public, anon;
grant execute on function public.send_message_to_profile(
  uuid, text, text, public.message_content_type, text, integer, text, bigint, double precision, double precision
) to authenticated;

-- ---------------------------------------------------------------------------
-- RPC: inbox
-- ---------------------------------------------------------------------------

drop function if exists public.list_inbox();

create or replace function public.list_inbox()
returns table (
  protocol public.contact_protocol,
  display_name text,
  peer_profile_id uuid,
  peer_external_address text,
  peer_avatar_url text,
  peer_pronouns text,
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
      m.peer_profile_id,
      m.peer_external_address,
      m.created_at,
      m.content_type,
      m.body,
      m.duration_seconds,
      m.author_id,
      m.owner_id,
      m.read_at
    from public.messages m
    cross join me
    where me.uid is not null
      and m.owner_id = me.uid
      and m.protocol = 'internal'
      and m.peer_profile_id is not null
      and public.mailbox_has_renderable_content(m.body, m.content_type)
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
    where d.author_id <> d.owner_id
      and d.read_at is null
    group by d.peer_profile_id
  )
  select
    l.protocol,
    coalesce(nullif(trim(p.display_name), ''), 'Contatto') as display_name,
    l.peer_profile_id,
    l.peer_external_address,
    p.avatar_url as peer_avatar_url,
    p.pronouns as peer_pronouns,
    case
      when l.content_type = 'gif' then '[GIF]'
      when l.content_type = 'voice' then public.format_voice_preview(coalesce(l.duration_seconds, 0))
      when l.content_type = 'location' then public.format_location_preview()
      else left(trim(l.body), 120)
    end as last_message_preview,
    l.last_message_at,
    coalesce(u.unread_count, 0) as unread_count
  from latest l
  left join public.profiles p on p.id = l.peer_profile_id
  left join unread u on u.peer_profile_id = l.peer_profile_id
  order by l.last_message_at desc nulls last;
$$;

grant execute on function public.list_inbox() to authenticated;
revoke all on function public.list_inbox() from anon;

-- ---------------------------------------------------------------------------
-- RPC: peer history
-- ---------------------------------------------------------------------------

drop function if exists public.list_peer_messages(uuid, integer);

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
    and m.owner_id = auth.uid()
    and m.peer_profile_id = p_peer_profile_id
    and public.mailbox_has_renderable_content(m.body, m.content_type)
  order by m.created_at asc
  limit greatest(1, least(coalesce(p_limit, 100), 500));
$$;

grant execute on function public.list_peer_messages(uuid, integer) to authenticated;
revoke all on function public.list_peer_messages(uuid, integer) from anon;

-- ---------------------------------------------------------------------------
-- RPC: mark read (local + signal sender read_at)
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

  update public.messages m
  set read_at = now()
  where m.owner_id = v_me
    and m.peer_profile_id = p_peer_profile_id
    and m.author_id = p_peer_profile_id
    and m.read_at is null
    and public.mailbox_has_renderable_content(m.body, m.content_type);

  update public.messages sender_copy
  set read_at = now()
  from public.messages incoming
  where incoming.owner_id = v_me
    and incoming.peer_profile_id = p_peer_profile_id
    and incoming.author_id = p_peer_profile_id
    and incoming.read_at is not null
    and sender_copy.owner_id = p_peer_profile_id
    and sender_copy.author_id = p_peer_profile_id
    and sender_copy.logical_message_id = incoming.logical_message_id
    and sender_copy.read_at is null;
end;
$$;

grant execute on function public.mark_peer_read(uuid) to authenticated;
revoke all on function public.mark_peer_read(uuid) from anon;
