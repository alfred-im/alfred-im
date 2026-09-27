-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- Broadcast archive row: peer_address = group address (destination = group).
-- Column is NOT NULL. UNIQUE (archive_user_id, logical_message_id, peer_address)
-- stays for fanout legs, not because of NULL.

-- ---------------------------------------------------------------------------
-- broadcast_message_to_allowlist: insert peer_address = v_group_address
-- (recreated from 20260913100000_peer_address_identity.sql)
-- ---------------------------------------------------------------------------

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
  v_sender_message_id uuid;
  v_row public.messages;
  v_existing_id uuid;
  v_body text := coalesce(p_body, '');
  v_media_url text := nullif(trim(coalesce(p_media_url, '')), '');
  v_media_mime text := nullif(trim(coalesce(p_media_mime, '')), '');
  v_participant_count integer;
  v_outbox_id uuid;
  v_group_address text := public.profile_bare_address(v_me);
begin
  if v_me is null then
    raise exception 'not authenticated';
  end if;

  perform public.assert_profile_active(v_me);

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
  elsif p_content_type = 'voice' then
    if v_media_url is null then
      raise exception 'voice requires media_url';
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
    and r.allowed_address is not null
    and r.allowed_address <> v_group_address;

  if v_participant_count = 0 then
    raise exception 'no allow list recipients';
  end if;

  v_sender_message_id := gen_random_uuid();

  insert into public.messages (
    archive_user_id,
    author_id,
    original_author_id,
    peer_address,
    author_address,
    logical_message_id,
    client_message_id,
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
    v_group_address,
    v_group_address,
    v_sender_message_id,
    p_client_message_id,
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

  insert into public.outbox (message_id, payload, status)
  values (
    v_row.id,
    jsonb_build_object(
      'event_kind', 'group_erogate',
      'logical_message_id', v_sender_message_id,
      'sender_id', v_me,
      'broadcast', true,
      'body', trim(v_body),
      'content_type', p_content_type
    ),
    'queued'
  )
  returning id into v_outbox_id;

  perform alfred_delivery.process_outbox(v_outbox_id);

  return v_row;
end;
$$;

-- ---------------------------------------------------------------------------
-- Backfill existing NULL peer_address rows.
-- Expected leftovers before this migration: broadcast archive rows inserted
-- with peer_address NULL (author_id = original_author_id = archive group).
-- Safe extra fills:
--   * legacy broadcast (original_author_id unset, same author=archive=group)
--   * inbound (author_id <> archive): conversation key = author_address
-- Unclassifiable leftovers (e.g. outbound 1:1 or fanout without member
-- address) RAISE — do not SET NOT NULL over unknown data.
-- ---------------------------------------------------------------------------

update public.messages m
set peer_address = public.profile_bare_address(m.archive_user_id)
from public.profiles p
where m.peer_address is null
  and p.id = m.archive_user_id
  and p.profile_kind = 'group'
  and m.author_id = m.archive_user_id
  and m.original_author_id = m.archive_user_id;

update public.messages m
set peer_address = public.profile_bare_address(m.archive_user_id)
from public.profiles p
where m.peer_address is null
  and p.id = m.archive_user_id
  and p.profile_kind = 'group'
  and m.author_id = m.archive_user_id
  and m.original_author_id is null;

update public.messages m
set peer_address = public.normalize_address(m.author_address)
where m.peer_address is null
  and m.author_address is not null
  and public.normalize_address(m.author_address) <> ''
  and m.author_id is distinct from m.archive_user_id;

do $$
declare
  v_leftover integer;
begin
  select count(*) into v_leftover
  from public.messages
  where peer_address is null;

  if v_leftover > 0 then
    raise exception
      'messages.peer_address still has % NULL row(s) after broadcast/inbound backfill; refusing SET NOT NULL',
      v_leftover;
  end if;
end $$;

alter table public.messages
  alter column peer_address set not null;

comment on column public.messages.peer_address is
  'Chiave conversazione lowercase (username o user@server). Broadcast archivio gruppo: indirizzo del gruppo.';
