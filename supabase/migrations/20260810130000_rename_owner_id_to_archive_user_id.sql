-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- Forward rename: mailbox column owner_id -> archive_user_id.
-- Replaces the in-place rewrite of historical migrations (commit a1f3a86).
-- Runs once after 20260810120000_peer_relationship_flags.sql on a schema that
-- still uses owner_id. reception_allowlist_owner_id_idx was dropped in
-- 20260809130000; sync_cursors_owner_thread_protocol_key_unique in 20260627230000.

-- ---------------------------------------------------------------------------
-- 1. Columns
-- ---------------------------------------------------------------------------

alter table public.contacts rename column owner_id to archive_user_id;
alter table public.messages rename column owner_id to archive_user_id;
alter table public.reception_allowlist rename column owner_id to archive_user_id;

-- ---------------------------------------------------------------------------
-- 2. Indexes (names only; definitions follow renamed columns)
-- ---------------------------------------------------------------------------

alter index public.contacts_owner_linked_profile_idx
  rename to contacts_archive_user_linked_profile_idx;

alter index public.contacts_owner_external_address_idx
  rename to contacts_archive_user_external_address_idx;

alter index public.contacts_owner_id_idx
  rename to contacts_archive_user_id_idx;

alter index public.messages_owner_client_id_idx
  rename to messages_archive_user_client_id_idx;

alter index public.messages_owner_logical_id_idx
  rename to messages_archive_user_logical_id_idx;

alter index public.messages_owner_peer_created_idx
  rename to messages_archive_user_peer_created_idx;

-- ---------------------------------------------------------------------------
-- 3. Constraints (reception_allowlist)
-- ---------------------------------------------------------------------------

alter table public.reception_allowlist
  rename constraint reception_allowlist_owner_id_fkey
  to reception_allowlist_archive_user_id_fkey;

alter table public.reception_allowlist
  rename constraint reception_allowlist_owner_allowed_unique
  to reception_allowlist_archive_user_allowed_unique;

-- ---------------------------------------------------------------------------
-- 4. sync_cursors constraint (column is profile_id; legacy naming only)
-- ---------------------------------------------------------------------------

alter table public.sync_cursors
  rename constraint sync_cursors_owner_peer_protocol_key_unique
  to sync_cursors_archive_user_peer_protocol_key_unique;

-- ---------------------------------------------------------------------------
-- 5. RPC rename: list_owner_messages -> list_archive_messages
-- ---------------------------------------------------------------------------

alter function public.list_owner_messages(integer)
  rename to list_archive_messages;

-- ---------------------------------------------------------------------------
-- 6. Function bodies — only RPC that referenced owner_id in historical migrations
-- ---------------------------------------------------------------------------

-- public.get_or_create_conversation_from_contact (from 20260624200000_alfred_domain_schema.sql)
create or replace function public.get_or_create_conversation_from_contact(p_contact_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_contact public.contacts%rowtype;
  v_conv_id uuid;
begin
  if v_me is null then
    raise exception 'not authenticated';
  end if;

  select * into v_contact
  from public.contacts
  where id = p_contact_id and archive_user_id = v_me;

  if not found then
    raise exception 'contact not found';
  end if;

  if v_contact.protocol = 'internal' then
    return public.get_or_create_direct_conversation(v_contact.linked_profile_id);
  end if;

  select cp.conversation_id into v_conv_id
  from public.conversation_participants cp
  inner join public.conversations c on c.id = cp.conversation_id
  where cp.profile_id = v_me
    and cp.contact_id = p_contact_id
    and c.is_group = false
  limit 1;

  if v_conv_id is not null then
    return v_conv_id;
  end if;

  insert into public.conversations (protocol, is_group, title)
  values (v_contact.protocol, false, v_contact.display_name)
  returning id into v_conv_id;

  insert into public.conversation_participants (conversation_id, profile_id, contact_id)
  values (v_conv_id, v_me, p_contact_id);

  return v_conv_id;
end;
$$;

-- public.send_message_to_profile (from 20260801100000_reception_outbound_gate.sql)
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
set search_path = public, alfred_delivery
as $$
declare
  v_me uuid := auth.uid();
  v_lambda uuid;
  v_sender_id uuid;
  v_row public.messages;
  v_body text := coalesce(p_body, '');
  v_media_url text := nullif(trim(coalesce(p_media_url, '')), '');
  v_media_mime text := nullif(trim(coalesce(p_media_mime, '')), '');
  v_recipient_kind public.profile_kind;
  v_sender_kind public.profile_kind;
  v_content_author uuid;
  v_outbox_id uuid;
  v_outbox_payload jsonb;
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
    where m.archive_user_id = v_me
      and m.client_message_id = p_client_message_id
    limit 1;

    if v_sender_id is not null then
      select * into v_row from public.messages where id = v_sender_id;
      return v_row;
    end if;
  end if;

  if not public.is_sender_allowed_for_reception(v_me, p_recipient_profile_id) then
    raise exception 'recipient not in reception allowlist';
  end if;

  if p_content_type = 'text' then
    if length(trim(v_body)) = 0 then
      raise exception 'empty message';
    end if;
  elsif p_content_type = 'gif' then
    if v_media_url is null then
      raise exception 'gif requires media_url';
    end if;
  elsif p_content_type = 'image' then
    if v_media_url is null then
      raise exception 'image requires media_url';
    end if;
    if v_media_mime is null then
      raise exception 'image requires media_mime';
    end if;
    if v_media_mime not in ('image/jpeg', 'image/png', 'image/webp') then
      raise exception 'invalid image media_mime';
    end if;
    if p_media_size_bytes is not null and p_media_size_bytes <= 0 then
      raise exception 'invalid media_size_bytes';
    end if;
  elsif p_content_type = 'video' then
    if v_media_url is null then
      raise exception 'video requires media_url';
    end if;
    if v_media_mime is null then
      raise exception 'video requires media_mime';
    end if;
    if v_media_mime not in ('video/mp4', 'video/webm') then
      raise exception 'invalid video media_mime';
    end if;
    if p_duration_seconds is null or p_duration_seconds <= 0 then
      raise exception 'video requires duration_seconds';
    end if;
    if p_media_size_bytes is not null and p_media_size_bytes <= 0 then
      raise exception 'invalid media_size_bytes';
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

  v_recipient_kind := public.profile_kind_of(p_recipient_profile_id);
  v_sender_kind := public.profile_kind_of(v_me);
  v_content_author := case
    when v_recipient_kind = 'group' or v_sender_kind = 'group' then v_me
    else null
  end;
  v_lambda := gen_random_uuid();

  insert into public.messages (
    archive_user_id,
    author_id,
    original_author_id,
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
    v_content_author,
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

  v_outbox_payload := jsonb_build_object(
    'event_kind', 'deliver',
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
  );

  insert into public.outbox (message_id, protocol, payload, status)
  values (v_sender_id, 'internal', v_outbox_payload, 'queued')
  returning id into v_outbox_id;

  perform alfred_delivery.process_outbox(v_outbox_id);

  select * into v_row from public.messages where id = v_sender_id;
  return v_row;
end;
$$;

-- public.list_inbox (from 20260810120000_peer_relationship_flags.sql)
create or replace function public.list_inbox()
returns table (
  protocol public.contact_protocol,
  display_name text,
  peer_profile_id uuid,
  peer_external_address text,
  peer_avatar_url text,
  peer_cover_url text,
  peer_pronouns text,
  peer_profile_kind public.profile_kind,
  peer_in_contacts boolean,
  peer_is_allowed boolean,
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
      m.archive_user_id,
      m.read_at
    from public.messages m
    cross join me
    where me.uid is not null
      and m.archive_user_id = me.uid
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
    where d.author_id <> d.archive_user_id
      and d.read_at is null
    group by d.peer_profile_id
  )
  select
    l.protocol,
    coalesce(nullif(trim(p.display_name), ''), 'Contatto') as display_name,
    l.peer_profile_id,
    l.peer_external_address,
    p.avatar_url as peer_avatar_url,
    p.cover_url as peer_cover_url,
    p.pronouns as peer_pronouns,
    coalesce(p.profile_kind, 'user'::public.profile_kind) as peer_profile_kind,
    coalesce(rel.peer_in_contacts, false) as peer_in_contacts,
    coalesce(rel.peer_is_allowed, false) as peer_is_allowed,
    case
      when l.content_type = 'gif' then '[GIF]'
      when l.content_type = 'image' then
        case
          when length(trim(l.body)) > 0 then '📷 ' || left(trim(l.body), 100)
          else '📷 Foto'
        end
      when l.content_type = 'video' then
        case
          when length(trim(l.body)) > 0 then '🎬 ' || left(trim(l.body), 100)
          else '🎬 Video'
        end
      when l.content_type = 'voice' then public.format_voice_preview(coalesce(l.duration_seconds, 0))
      when l.content_type = 'location' then public.format_location_preview()
      else left(trim(l.body), 120)
    end as last_message_preview,
    l.last_message_at,
    coalesce(u.unread_count, 0) as unread_count
  from latest l
  left join public.profiles p on p.id = l.peer_profile_id
  left join unread u on u.peer_profile_id = l.peer_profile_id
  left join lateral public.peer_relationship_for_viewer(l.peer_profile_id) rel on true
  order by l.last_message_at desc nulls last;
$$;

-- public.list_peer_messages (from 20260719220000_list_peer_messages_recent_window.sql)
create or replace function public.list_peer_messages(
  p_peer_profile_id uuid,
  p_limit integer default 100,
  p_before_created_at timestamptz default null
)
returns setof public.messages
language sql
stable
security definer
set search_path = public
as $$
  with bounded as (
    select m.*
    from public.messages m
    where auth.uid() is not null
      and p_peer_profile_id is not null
      and m.archive_user_id = auth.uid()
      and m.peer_profile_id = p_peer_profile_id
      and public.mailbox_has_renderable_content(m.body, m.content_type)
      and (
        p_before_created_at is null
        or m.created_at < p_before_created_at
      )
    order by m.created_at desc
    limit greatest(1, least(coalesce(p_limit, 100), 500))
  )
  select b.*
  from bounded b
  order by b.created_at asc;
$$;

-- public.mark_peer_read (from 20260711190000_account_boundary_delivery.sql)
create or replace function public.mark_peer_read(p_peer_profile_id uuid)
returns void
language plpgsql
security definer
set search_path = public, alfred_delivery
as $$
declare
  v_me uuid := auth.uid();
  v_lambda uuid;
  v_incoming_id uuid;
  v_outbox_id uuid;
begin
  if v_me is null then
    raise exception 'not authenticated';
  end if;

  if p_peer_profile_id is null then
    raise exception 'peer required';
  end if;

  for v_lambda, v_incoming_id in
    update public.messages m
    set read_at = now()
    where m.archive_user_id = v_me
      and m.peer_profile_id = p_peer_profile_id
      and m.author_id = p_peer_profile_id
      and m.read_at is null
      and public.mailbox_has_renderable_content(m.body, m.content_type)
    returning m.logical_message_id, m.id
  loop
    insert into public.outbox (message_id, protocol, payload, status)
    values (
      v_incoming_id,
      'internal',
      jsonb_build_object(
        'event_kind', 'read_receipt',
        'logical_message_id', v_lambda,
        'reader_id', v_me,
        'sender_profile_id', p_peer_profile_id
      ),
      'queued'
    )
    returning id into v_outbox_id;

    perform alfred_delivery.process_outbox(v_outbox_id);
  end loop;
end;
$$;

-- public.is_sender_allowed_for_reception (from 20260704130000_reception_allowlist.sql)
drop function if exists public.is_sender_allowed_for_reception(uuid, uuid);
create or replace function public.is_sender_allowed_for_reception(
  p_archive_user_id uuid,
  p_sender_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.reception_allowlist r
    where r.archive_user_id = p_archive_user_id
      and r.allowed_profile_id = p_sender_profile_id
  );
$$;

-- public.is_bidirectional_allowed (from 20260725100000_delivery_internal_helpers.sql)
drop function if exists public.is_bidirectional_allowed(uuid, uuid, uuid);
create or replace function public.is_bidirectional_allowed(
  p_archive_user_a uuid,
  p_archive_user_b uuid,
  p_sender uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_sender_allowed_for_reception(p_archive_user_a, p_archive_user_b)
     and public.is_sender_allowed_for_reception(p_archive_user_b, p_archive_user_a);
$$;

-- public.erogate_group_message (from 20260706120000_group_accounts.sql)
create or replace function public.erogate_group_message(
  p_group_id uuid,
  p_original_author_id uuid,
  p_lambda uuid,
  p_protocol public.contact_protocol,
  p_body text,
  p_content_type public.message_content_type,
  p_media_url text,
  p_duration_seconds integer,
  p_media_mime text,
  p_media_size_bytes bigint,
  p_latitude double precision,
  p_longitude double precision
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_participant uuid;
begin
  for v_participant in
    select r.allowed_profile_id
    from public.reception_allowlist r
    where r.archive_user_id = p_group_id
      and r.allowed_profile_id is not null
      and r.allowed_profile_id <> p_group_id
      and r.allowed_profile_id <> p_original_author_id
  loop
    if not public.is_sender_allowed_for_reception(v_participant, p_group_id) then
      continue;
    end if;

    insert into public.messages (
      archive_user_id,
      author_id,
      original_author_id,
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
      v_participant,
      p_group_id,
      p_original_author_id,
      p_group_id,
      p_lambda,
      p_protocol,
      p_body,
      p_content_type,
      p_media_url,
      p_duration_seconds,
      p_media_mime,
      p_media_size_bytes,
      p_latitude,
      p_longitude
    )
    on conflict (archive_user_id, logical_message_id) do nothing;
  end loop;
end;
$$;

-- public.broadcast_message_to_allowlist (from 20260713100001_message_image_video_support.sql)
create or replace function public.broadcast_message_to_allowlist(
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
set search_path = public, alfred_delivery
as $$
declare
  v_me uuid := auth.uid();
  v_kind public.profile_kind;
  v_lambda uuid;
  v_row public.messages;
  v_existing_id uuid;
  v_body text := coalesce(p_body, '');
  v_media_url text := nullif(trim(coalesce(p_media_url, '')), '');
  v_media_mime text := nullif(trim(coalesce(p_media_mime, '')), '');
  v_participant_count integer;
  v_outbox_id uuid;
begin
  if v_me is null then
    raise exception 'not authenticated';
  end if;

  v_kind := public.profile_kind_of(v_me);
  if v_kind <> 'group' then
    raise exception 'only group accounts can broadcast';
  end if;

  if p_client_message_id is not null then
    select m.id into v_existing_id
    from public.messages m
    where m.archive_user_id = v_me
      and m.client_message_id = p_client_message_id
    limit 1;

    if v_existing_id is not null then
      select * into v_row from public.messages where id = v_existing_id;
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
  elsif p_content_type = 'image' then
    if v_media_url is null then
      raise exception 'image requires media_url';
    end if;
    if v_media_mime is null then
      raise exception 'image requires media_mime';
    end if;
    if v_media_mime not in ('image/jpeg', 'image/png', 'image/webp') then
      raise exception 'invalid image media_mime';
    end if;
    if p_media_size_bytes is not null and p_media_size_bytes <= 0 then
      raise exception 'invalid media_size_bytes';
    end if;
  elsif p_content_type = 'video' then
    if v_media_url is null then
      raise exception 'video requires media_url';
    end if;
    if v_media_mime is null then
      raise exception 'video requires media_mime';
    end if;
    if v_media_mime not in ('video/mp4', 'video/webm') then
      raise exception 'invalid video media_mime';
    end if;
    if p_duration_seconds is null or p_duration_seconds <= 0 then
      raise exception 'video requires duration_seconds';
    end if;
    if p_media_size_bytes is not null and p_media_size_bytes <= 0 then
      raise exception 'invalid media_size_bytes';
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
  elsif p_content_type = 'location' then
    if p_latitude is null or p_longitude is null then
      raise exception 'location requires latitude and longitude';
    end if;
  else
    raise exception 'unsupported content_type';
  end if;

  select count(*) into v_participant_count
  from public.reception_allowlist r
  where r.archive_user_id = v_me
    and r.allowed_profile_id is not null
    and r.allowed_profile_id <> v_me;

  if v_participant_count = 0 then
    raise exception 'no allow list recipients';
  end if;

  v_lambda := gen_random_uuid();

  insert into public.messages (
    archive_user_id,
    author_id,
    original_author_id,
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
    v_me,
    null,
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
  returning * into v_row;

  insert into public.outbox (message_id, protocol, payload, status)
  values (
    v_row.id,
    'internal',
    jsonb_build_object(
      'event_kind', 'group_erogate',
      'logical_message_id', v_lambda,
      'sender_id', v_me,
      'broadcast', true,
      'body', trim(v_body),
      'content_type', p_content_type,
      'client_message_id', p_client_message_id
    ),
    'queued'
  )
  returning id into v_outbox_id;

  perform alfred_delivery.process_outbox(v_outbox_id);

  return v_row;
end;
$$;

-- public.list_archive_messages (from 20260706120000_group_accounts.sql)
create or replace function public.list_archive_messages(
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
  where m.archive_user_id = auth.uid()
    and public.mailbox_has_renderable_content(m.body, m.content_type)
  order by m.created_at asc
  limit greatest(coalesce(p_limit, 100), 1);
$$;

-- alfred_delivery.erogate_group_message (from 20260714100000_push_subscriptions.sql)
create or replace function alfred_delivery.erogate_group_message(
  p_group_id uuid,
  p_original_author_id uuid,
  p_lambda uuid,
  p_protocol public.contact_protocol,
  p_body text,
  p_content_type public.message_content_type,
  p_media_url text,
  p_duration_seconds integer,
  p_media_mime text,
  p_media_size_bytes bigint,
  p_latitude double precision,
  p_longitude double precision
)
returns void
language plpgsql
security definer
set search_path = public, alfred_delivery
as $$
declare
  v_participant uuid;
  v_row_count integer;
begin
  for v_participant in
    select r.allowed_profile_id
    from public.reception_allowlist r
    where r.archive_user_id = p_group_id
      and r.allowed_profile_id is not null
      and r.allowed_profile_id <> p_group_id
      and r.allowed_profile_id <> p_original_author_id
  loop
    if not public.is_sender_allowed_for_reception(v_participant, p_group_id) then
      continue;
    end if;

    insert into public.messages (
      archive_user_id,
      author_id,
      original_author_id,
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
      v_participant,
      p_group_id,
      p_original_author_id,
      p_group_id,
      p_lambda,
      p_protocol,
      p_body,
      p_content_type,
      p_media_url,
      p_duration_seconds,
      p_media_mime,
      p_media_size_bytes,
      p_latitude,
      p_longitude
    )
    on conflict (archive_user_id, logical_message_id) do nothing;

    get diagnostics v_row_count = row_count;

    if v_row_count > 0 then
      perform alfred_delivery.queue_push_after_delivery(
        v_participant,
        p_group_id,
        p_lambda,
        p_content_type,
        p_body,
        p_original_author_id
      );
    end if;
  end loop;
end;
$$;

-- alfred_delivery.propagate_read_receipt (from 20260711190000_account_boundary_delivery.sql)
create or replace function alfred_delivery.propagate_read_receipt(
  p_logical_message_id uuid,
  p_sender_profile_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, alfred_delivery
as $$
begin
  update public.messages sender_copy
  set read_at = now()
  where sender_copy.archive_user_id = p_sender_profile_id
    and sender_copy.logical_message_id = p_logical_message_id
    and sender_copy.read_at is null;
end;
$$;

-- alfred_delivery.deliver_internal (from 20260725100000_delivery_internal_helpers.sql)
create or replace function alfred_delivery.deliver_internal(p_outbox_id uuid)
returns void
language plpgsql
security definer
set search_path = public, alfred_delivery
as $$
declare
  v_outbox public.outbox;
  v_payload jsonb;
  v_sender_id uuid;
  v_sender public.messages;
  v_recipient_id uuid;
  v_recipient_kind public.profile_kind;
  v_sender_kind public.profile_kind;
  v_allowed boolean;
  v_lambda uuid;
  v_content_author uuid;
  v_body text;
  v_content_type public.message_content_type;
  v_is_group boolean;
  v_original_author_id uuid;
  v_row_count integer;
begin
  v_outbox := alfred_delivery._claim_outbox(p_outbox_id);
  if v_outbox.status = 'completed' then
    return;
  end if;

  v_payload := v_outbox.payload;
  v_sender_id := v_outbox.message_id;

  select * into v_sender from public.messages where id = v_sender_id;
  if v_sender.id is null then
    raise exception 'sender message not found for outbox %', p_outbox_id;
  end if;

  v_recipient_id := (v_payload ->> 'recipient_profile_id')::uuid;
  v_lambda := coalesce(
    (v_payload ->> 'logical_message_id')::uuid,
    v_sender.logical_message_id
  );
  v_body := coalesce(v_payload ->> 'body', v_sender.body);
  v_content_type := coalesce(
    (v_payload ->> 'content_type')::public.message_content_type,
    v_sender.content_type
  );

  v_recipient_kind := public.profile_kind_of(v_recipient_id);
  v_sender_kind := public.profile_kind_of(v_sender.archive_user_id);
  v_content_author := case
    when v_recipient_kind = 'group' or v_sender_kind = 'group' then v_sender.archive_user_id
    else null
  end;

  v_is_group := v_recipient_kind = 'group';
  v_original_author_id := case
    when v_is_group then v_sender.archive_user_id
    else v_content_author
  end;

  if v_is_group then
    v_allowed := public.is_bidirectional_allowed(
      v_recipient_id,
      v_sender.archive_user_id,
      v_sender.archive_user_id
    );
  else
    v_allowed := public.is_sender_allowed_for_reception(v_recipient_id, v_sender.archive_user_id);
  end if;

  if v_allowed then
    v_row_count := alfred_delivery._insert_recipient_copy(
      v_recipient_id,
      v_sender.archive_user_id,
      v_original_author_id,
      v_sender.archive_user_id,
      v_lambda,
      coalesce(v_sender.protocol, 'internal'::public.contact_protocol),
      v_body,
      v_content_type,
      v_payload,
      v_sender
    );

    update public.messages
    set delivered_at = now()
    where id = v_sender_id
      and delivered_at is null;

    if v_is_group then
      perform alfred_delivery.erogate_group_message(
        v_recipient_id,
        v_sender.archive_user_id,
        v_lambda,
        coalesce(v_sender.protocol, 'internal'::public.contact_protocol),
        v_body,
        v_content_type,
        coalesce(v_payload ->> 'media_url', v_sender.media_url),
        coalesce((v_payload ->> 'duration_seconds')::integer, v_sender.duration_seconds),
        coalesce(v_payload ->> 'media_mime', v_sender.media_mime),
        coalesce((v_payload ->> 'media_size_bytes')::bigint, v_sender.media_size_bytes),
        coalesce((v_payload ->> 'latitude')::double precision, v_sender.latitude),
        coalesce((v_payload ->> 'longitude')::double precision, v_sender.longitude)
      );

      perform alfred_delivery.queue_push_after_delivery(
        v_recipient_id,
        v_sender.archive_user_id,
        v_lambda,
        v_content_type,
        v_body,
        v_sender.archive_user_id
      );
    elsif v_row_count > 0 then
      perform alfred_delivery.queue_push_after_delivery(
        v_recipient_id,
        v_sender.archive_user_id,
        v_lambda,
        v_content_type,
        v_body,
        v_content_author
      );
    end if;

    perform alfred_delivery._complete_outbox(p_outbox_id);
  else
    perform alfred_delivery._complete_outbox(
      p_outbox_id,
      v_payload || jsonb_build_object('reception_rejected', true)
    );
  end if;
end;
$$;

-- alfred_delivery.group_erogate (from 20260725100000_delivery_internal_helpers.sql)
create or replace function alfred_delivery.group_erogate(p_outbox_id uuid)
returns void
language plpgsql
security definer
set search_path = public, alfred_delivery
as $$
declare
  v_outbox public.outbox;
  v_group_row public.messages;
begin
  v_outbox := alfred_delivery._claim_outbox(p_outbox_id);
  if v_outbox.status = 'completed' then
    return;
  end if;

  select * into v_group_row from public.messages where id = v_outbox.message_id;
  if v_group_row.id is null then
    raise exception 'group message not found for outbox %', p_outbox_id;
  end if;

  perform alfred_delivery.erogate_group_message(
    v_group_row.archive_user_id,
    v_group_row.archive_user_id,
    v_group_row.logical_message_id,
    v_group_row.protocol,
    v_group_row.body,
    v_group_row.content_type,
    v_group_row.media_url,
    v_group_row.duration_seconds,
    v_group_row.media_mime,
    v_group_row.media_size_bytes,
    v_group_row.latitude,
    v_group_row.longitude
  );

  perform alfred_delivery._complete_outbox(p_outbox_id);
end;
$$;

-- alfred_delivery.queue_push_after_delivery (from 20260715210000_push_recipient_account_label.sql)
create or replace function alfred_delivery.queue_push_after_delivery(
  p_recipient_user_id uuid,
  p_peer_profile_id uuid,
  p_logical_message_id uuid,
  p_content_type public.message_content_type,
  p_body text,
  p_original_author_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public, alfred_delivery
as $$
declare
  v_recipient_message_id uuid;
  v_peer_name text;
  v_recipient_name text;
  v_recipient_username text;
  v_preview text;
  v_author_name text;
  v_payload jsonb;
  v_outbox_id uuid;
begin
  if p_recipient_user_id is null or p_peer_profile_id is null or p_logical_message_id is null then
    return;
  end if;

  if not exists (
    select 1 from public.push_subscriptions ps where ps.user_id = p_recipient_user_id
  ) then
    return;
  end if;

  select m.id
  into v_recipient_message_id
  from public.messages m
  where m.archive_user_id = p_recipient_user_id
    and m.logical_message_id = p_logical_message_id
  limit 1;

  if v_recipient_message_id is null then
    return;
  end if;

  select p.display_name into v_peer_name
  from public.profiles p
  where p.id = p_peer_profile_id;

  select p.display_name, p.username
  into v_recipient_name, v_recipient_username
  from public.profiles p
  where p.id = p_recipient_user_id;

  v_preview := public.message_preview_text(p_content_type, p_body);

  if p_original_author_id is not null
     and p_original_author_id <> p_peer_profile_id then
    select p.display_name into v_author_name
    from public.profiles p
    where p.id = p_original_author_id;

    if v_author_name is not null and length(trim(v_author_name)) > 0 then
      v_preview := v_author_name || ': ' || v_preview;
    end if;
  end if;

  v_payload := jsonb_build_object(
    'event_kind', 'push_notify',
    'recipient_user_id', p_recipient_user_id,
    'recipient_display_name', coalesce(v_recipient_name, 'Alfred'),
    'recipient_username', v_recipient_username,
    'peer_profile_id', p_peer_profile_id,
    'peer_display_name', coalesce(v_peer_name, 'Alfred'),
    'preview_text', v_preview,
    'logical_message_id', p_logical_message_id,
    'content_type', p_content_type::text
  );

  insert into public.outbox (message_id, protocol, payload, status)
  values (v_recipient_message_id, 'internal', v_payload, 'queued')
  returning id into v_outbox_id;

  perform alfred_delivery.process_push_notify(v_outbox_id);
end;
$$;

-- alfred_delivery._insert_recipient_copy (from 20260725100000_delivery_internal_helpers.sql)
create or replace function alfred_delivery._insert_recipient_copy(
  p_recipient_id uuid,
  p_author_id uuid,
  p_original_author_id uuid,
  p_peer_profile_id uuid,
  p_lambda uuid,
  p_protocol public.contact_protocol,
  p_body text,
  p_content_type public.message_content_type,
  p_payload jsonb,
  p_sender public.messages
)
returns integer
language plpgsql
security definer
set search_path = public, alfred_delivery
as $$
declare
  v_row_count integer;
begin
  insert into public.messages (
    archive_user_id,
    author_id,
    original_author_id,
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
    p_recipient_id,
    p_author_id,
    p_original_author_id,
    p_peer_profile_id,
    p_lambda,
    p_protocol,
    p_body,
    p_content_type,
    coalesce(p_payload ->> 'media_url', p_sender.media_url),
    coalesce((p_payload ->> 'duration_seconds')::integer, p_sender.duration_seconds),
    coalesce(p_payload ->> 'media_mime', p_sender.media_mime),
    coalesce((p_payload ->> 'media_size_bytes')::bigint, p_sender.media_size_bytes),
    coalesce((p_payload ->> 'latitude')::double precision, p_sender.latitude),
    coalesce((p_payload ->> 'longitude')::double precision, p_sender.longitude)
  )
  on conflict (archive_user_id, logical_message_id) do nothing;

  get diagnostics v_row_count = row_count;
  return v_row_count;
end;
$$;

-- public.mailbox_is_message_participant (from 20260807200000_message_reaction_facts.sql)
create or replace function public.mailbox_is_message_participant(
  p_logical_message_id uuid,
  p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.messages m
    where m.logical_message_id = p_logical_message_id
      and m.archive_user_id = p_user_id
  );
$$;

-- public.list_message_reactions (from 20260807200000_message_reaction_facts.sql)
create or replace function public.list_message_reactions(
  p_logical_message_ids uuid[]
)
returns table (
  logical_message_id uuid,
  emoji text,
  reaction_count bigint,
  reactor_ids uuid[],
  includes_me boolean
)
language sql
stable
security definer
set search_path = public
as $$
  with scoped as (
    select distinct m.logical_message_id
    from public.messages m
    where m.archive_user_id = auth.uid()
      and m.logical_message_id = any (p_logical_message_ids)
  ),
  latest as (
    select distinct on (f.logical_message_id, f.reactor_id)
      f.logical_message_id,
      f.reactor_id,
      f.kind,
      f.emoji
    from public.message_reaction_facts f
    inner join scoped s on s.logical_message_id = f.logical_message_id
    order by f.logical_message_id, f.reactor_id, f.occurred_at desc, f.id desc
  ),
  active as (
    select
      l.logical_message_id,
      l.reactor_id,
      l.emoji
    from latest l
    where l.kind = 'applied'
  )
  select
    a.logical_message_id,
    a.emoji,
    count(*)::bigint as reaction_count,
    array_agg(a.reactor_id order by a.reactor_id) as reactor_ids,
    bool_or(a.reactor_id = auth.uid()) as includes_me
  from active a
  group by a.logical_message_id, a.emoji
  order by a.logical_message_id, a.emoji;
$$;

-- public.peer_relationship_for_viewer (from 20260810120000_peer_relationship_flags.sql)
create or replace function public.peer_relationship_for_viewer(p_peer_profile_id uuid)
returns table (
  peer_in_contacts boolean,
  peer_is_allowed boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    exists (
      select 1
      from public.contacts c
      where c.archive_user_id = auth.uid()
        and c.protocol = 'internal'
        and c.linked_profile_id = p_peer_profile_id
    ) as peer_in_contacts,
    exists (
      select 1
      from public.reception_allowlist r
      where r.archive_user_id = auth.uid()
        and r.allowed_profile_id = p_peer_profile_id
    ) as peer_is_allowed
  where auth.uid() is not null
    and p_peer_profile_id is not null
    and p_peer_profile_id <> auth.uid();
$$;

-- ---------------------------------------------------------------------------
-- 7. Re-apply helper revokes (CREATE resets EXECUTE to PUBLIC by default)
--    Mirrors 20260707190000, 20260711190000, 20260714100000, 20260725100000,
--    20260807200000 — only for functions recreated above.
-- ---------------------------------------------------------------------------

revoke all on function public.is_sender_allowed_for_reception(uuid, uuid)
  from public, anon, authenticated;

revoke all on function public.is_bidirectional_allowed(uuid, uuid, uuid)
  from public, anon, authenticated;

revoke all on function public.erogate_group_message(
  uuid, uuid, uuid, public.contact_protocol, text, public.message_content_type,
  text, integer, text, bigint, double precision, double precision
) from public, anon, authenticated;

revoke all on function public.mailbox_is_message_participant(uuid, uuid)
  from public, anon, authenticated;

revoke all on function alfred_delivery.erogate_group_message(
  uuid, uuid, uuid, public.contact_protocol, text, public.message_content_type,
  text, integer, text, bigint, double precision, double precision
) from public, anon, authenticated;

revoke all on function alfred_delivery.propagate_read_receipt(uuid, uuid)
  from public, anon, authenticated;

revoke all on function alfred_delivery.deliver_internal(uuid)
  from public, anon, authenticated;

revoke all on function alfred_delivery.group_erogate(uuid)
  from public, anon, authenticated;

revoke all on function alfred_delivery.queue_push_after_delivery(
  uuid, uuid, uuid, public.message_content_type, text, uuid
) from public, anon, authenticated;

revoke all on function alfred_delivery._insert_recipient_copy(
  uuid, uuid, uuid, uuid, uuid, public.contact_protocol, text,
  public.message_content_type, jsonb, public.messages
) from public, anon, authenticated;

-- Legacy inbox_threads helper (obsolete after mailbox migration); still had owner_id body.
drop function if exists public.is_direct_message_visible(
  uuid, uuid, uuid, uuid
);

