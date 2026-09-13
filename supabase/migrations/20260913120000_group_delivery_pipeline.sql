-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- Group member erogation: fan-out via standard deliver outbox + deliver_internal
-- (see docs/decisions/group-delivery-pipeline-alignment.md)

-- ---------------------------------------------------------------------------
-- messages: allow multiple rows per λ on group archive (inbound + outbound legs)
-- ---------------------------------------------------------------------------

drop index if exists public.messages_archive_user_logical_id_idx;

create unique index messages_archive_user_logical_peer_idx
  on public.messages (archive_user_id, logical_message_id, peer_address)
  nulls not distinct;

-- ---------------------------------------------------------------------------
-- _insert_recipient_copy: conflict target includes peer_address
-- ---------------------------------------------------------------------------

create or replace function alfred_delivery._insert_recipient_copy(
  p_recipient_id uuid,
  p_author_id uuid,
  p_original_author_id uuid,
  p_peer_address text,
  p_author_address text,
  p_lambda uuid,
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
  if p_lambda is null then
    raise exception 'sender message id required for recipient copy';
  end if;

  if p_sender.logical_message_id is distinct from p_lambda then
    raise exception 'recipient copy must use sender-assigned message id';
  end if;

  insert into public.messages (
    archive_user_id,
    author_id,
    original_author_id,
    peer_address,
    author_address,
    logical_message_id,
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
    p_peer_address,
    p_author_address,
    p_lambda,
    p_body,
    p_content_type,
    coalesce(p_payload ->> 'media_url', p_sender.media_url),
    coalesce((p_payload ->> 'duration_seconds')::integer, p_sender.duration_seconds),
    coalesce(p_payload ->> 'media_mime', p_sender.media_mime),
    coalesce((p_payload ->> 'media_size_bytes')::bigint, p_sender.media_size_bytes),
    coalesce((p_payload ->> 'latitude')::double precision, p_sender.latitude),
    coalesce((p_payload ->> 'longitude')::double precision, p_sender.longitude)
  )
  on conflict (archive_user_id, logical_message_id, peer_address) do nothing;

  get diagnostics v_row_count = row_count;
  return v_row_count;
end;
$$;

-- ---------------------------------------------------------------------------
-- erogate_group_message: orchestrate N deliver outbox events (no direct INSERT)
-- ---------------------------------------------------------------------------

drop function if exists alfred_delivery.erogate_group_message(
  uuid, uuid, uuid, text, public.message_content_type,
  text, integer, text, bigint, double precision, double precision
);

create or replace function alfred_delivery.erogate_group_message(
  p_group_id uuid,
  p_original_author_id uuid,
  p_lambda uuid,
  p_body text,
  p_content_type public.message_content_type,
  p_media_url text,
  p_duration_seconds integer,
  p_media_mime text,
  p_media_size_bytes bigint,
  p_latitude double precision,
  p_longitude double precision,
  p_fanout_source_message_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public, alfred_delivery
as $$
declare
  v_participant_address text;
  v_participant uuid;
  v_group_address text := public.profile_bare_address(p_group_id);
  v_is_broadcast boolean := p_original_author_id = p_group_id;
  v_outbound_id uuid;
  v_outbox_id uuid;
  v_payload jsonb;
begin
  for v_participant_address in
    select r.allowed_address
    from public.reception_allowlist r
    where r.archive_user_id = p_group_id
      and r.allowed_address is not null
      and r.allowed_address <> v_group_address
      and r.allowed_address <> public.profile_bare_address(p_original_author_id)
  loop
    v_participant := public.resolve_local_profile_id(v_participant_address);

    if v_participant is null and not public.is_external_address(v_participant_address) then
      continue;
    end if;

    if v_participant is not null
       and not public.is_address_allowed_for_reception(v_participant, v_group_address) then
      continue;
    end if;

    if v_is_broadcast then
      v_outbound_id := p_fanout_source_message_id;
      if v_outbound_id is null then
        raise exception 'broadcast fanout requires source message id';
      end if;
    else
      insert into public.messages (
        archive_user_id,
        author_id,
        original_author_id,
        peer_address,
        author_address,
        logical_message_id,
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
        p_group_id,
        p_group_id,
        p_original_author_id,
        v_participant_address,
        v_group_address,
        p_lambda,
        p_body,
        p_content_type,
        p_media_url,
        p_duration_seconds,
        p_media_mime,
        p_media_size_bytes,
        p_latitude,
        p_longitude
      )
      on conflict (archive_user_id, logical_message_id, peer_address) do nothing
      returning id into v_outbound_id;

      if v_outbound_id is null then
        select m.id into v_outbound_id
        from public.messages m
        where m.archive_user_id = p_group_id
          and m.logical_message_id = p_lambda
          and m.peer_address = v_participant_address;
      end if;
    end if;

    if v_outbound_id is null then
      continue;
    end if;

    v_payload := jsonb_build_object(
      'event_kind', 'deliver',
      'logical_message_id', p_lambda,
      'recipient_address', v_participant_address,
      'group_erogation', true,
      'body', p_body,
      'content_type', p_content_type,
      'media_url', p_media_url,
      'duration_seconds', p_duration_seconds,
      'media_mime', p_media_mime,
      'media_size_bytes', p_media_size_bytes,
      'latitude', p_latitude,
      'longitude', p_longitude
    );

    insert into public.outbox (message_id, payload, status)
    values (v_outbound_id, v_payload, 'queued')
    returning id into v_outbox_id;

    perform alfred_delivery.process_outbox(v_outbox_id);
  end loop;
end;
$$;

revoke all on function alfred_delivery.erogate_group_message(
  uuid, uuid, uuid, text, public.message_content_type,
  text, integer, text, bigint, double precision, double precision, uuid
) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- deliver_internal: group → user erogation leg via standard pipeline
-- ---------------------------------------------------------------------------

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
  v_sender_message_id uuid;
  v_content_author uuid;
  v_body text;
  v_content_type public.message_content_type;
  v_is_group boolean;
  v_is_group_erogation boolean;
  v_original_author_id uuid;
  v_row_count integer;
  v_recipient_address text;
  v_recipient_peer_address text;
  v_recipient_author_address text;
  v_recipient_author_id uuid;
  v_group_address text;
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

  v_recipient_address := coalesce(
    v_payload ->> 'recipient_address',
    public.profile_bare_address((v_payload ->> 'recipient_profile_id')::uuid)
  );
  v_recipient_id := coalesce(
    (v_payload ->> 'recipient_profile_id')::uuid,
    public.resolve_local_profile_id(v_recipient_address)
  );

  if v_recipient_id is null and not public.is_external_address(v_recipient_address) then
    perform alfred_delivery._complete_outbox(
      p_outbox_id,
      v_payload || jsonb_build_object('reception_rejected', true, 'reason', 'recipient_not_found')
    );
    return;
  end if;

  if v_recipient_id is not null
     and (
       public.is_profile_disabled(v_sender.archive_user_id)
       or public.is_profile_disabled(v_recipient_id)
     ) then
    perform alfred_delivery._complete_outbox(p_outbox_id);
    return;
  end if;

  v_sender_message_id := v_sender.logical_message_id;
  if v_sender_message_id is null then
    raise exception 'sender message id missing on sender copy';
  end if;

  if (v_payload ? 'logical_message_id')
     and (v_payload ->> 'logical_message_id')::uuid is distinct from v_sender_message_id then
    raise exception 'outbox logical_message_id must match sender copy';
  end if;

  v_body := coalesce(v_payload ->> 'body', v_sender.body);
  v_content_type := coalesce(
    (v_payload ->> 'content_type')::public.message_content_type,
    v_sender.content_type
  );

  if v_recipient_id is null then
    perform alfred_delivery._complete_outbox(p_outbox_id);
    return;
  end if;

  v_recipient_kind := public.profile_kind_of(v_recipient_id);
  v_sender_kind := public.profile_kind_of(v_sender.archive_user_id);
  v_group_address := public.profile_bare_address(v_sender.archive_user_id);
  v_is_group := v_recipient_kind = 'group';
  v_is_group_erogation := v_sender_kind = 'group' and v_recipient_kind = 'user';

  v_content_author := case
    when v_is_group or v_sender_kind = 'group' then v_sender.archive_user_id
    else null
  end;

  v_original_author_id := case
    when v_is_group then v_sender.archive_user_id
    when v_is_group_erogation then v_sender.original_author_id
    else v_content_author
  end;

  if v_is_group then
    v_allowed := public.is_address_allowed_for_reception(v_recipient_id, v_sender.author_address)
      and public.is_address_allowed_for_reception(v_sender.archive_user_id, v_recipient_address);
    v_recipient_peer_address := v_sender.author_address;
    v_recipient_author_address := v_sender.author_address;
    v_recipient_author_id := v_sender.archive_user_id;
  elsif v_is_group_erogation then
    v_allowed := public.is_address_allowed_for_reception(v_recipient_id, v_sender.author_address)
      and public.is_address_allowed_for_reception(v_sender.archive_user_id, v_recipient_address);
    v_recipient_peer_address := v_group_address;
    v_recipient_author_address := v_group_address;
    v_recipient_author_id := v_sender.archive_user_id;
  else
    v_allowed := public.is_address_allowed_for_reception(v_recipient_id, v_sender.author_address);
    v_recipient_peer_address := v_sender.author_address;
    v_recipient_author_address := v_sender.author_address;
    v_recipient_author_id := null;
  end if;

  if v_allowed then
    v_row_count := alfred_delivery._insert_recipient_copy(
      v_recipient_id,
      v_recipient_author_id,
      v_original_author_id,
      v_recipient_peer_address,
      v_recipient_author_address,
      v_sender_message_id,
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
        v_sender_message_id,
        v_body,
        v_content_type,
        coalesce(v_payload ->> 'media_url', v_sender.media_url),
        coalesce((v_payload ->> 'duration_seconds')::integer, v_sender.duration_seconds),
        coalesce(v_payload ->> 'media_mime', v_sender.media_mime),
        coalesce((v_payload ->> 'media_size_bytes')::bigint, v_sender.media_size_bytes),
        coalesce((v_payload ->> 'latitude')::double precision, v_sender.latitude),
        coalesce((v_payload ->> 'longitude')::double precision, v_sender.longitude),
        null
      );

      perform alfred_delivery.queue_push_after_delivery(
        v_recipient_id,
        v_sender.author_address,
        v_sender_message_id,
        v_content_type,
        v_body,
        v_sender.archive_user_id
      );
    elsif v_row_count > 0 then
      perform alfred_delivery.queue_push_after_delivery(
        v_recipient_id,
        case when v_is_group_erogation then v_group_address else v_sender.author_address end,
        v_sender_message_id,
        v_content_type,
        v_body,
        coalesce(v_original_author_id, v_content_author)
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

-- ---------------------------------------------------------------------------
-- group_erogate: pass broadcast source row id into erogate orchestrator
-- ---------------------------------------------------------------------------

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
    v_group_row.body,
    v_group_row.content_type,
    v_group_row.media_url,
    v_group_row.duration_seconds,
    v_group_row.media_mime,
    v_group_row.media_size_bytes,
    v_group_row.latitude,
    v_group_row.longitude,
    v_group_row.id
  );

  perform alfred_delivery._complete_outbox(p_outbox_id);
end;
$$;

revoke all on function alfred_delivery.group_erogate(uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- materialize_inbound_sender_message: conflict target includes peer_address
-- ---------------------------------------------------------------------------

create or replace function alfred_delivery.materialize_inbound_sender_message(
  p_recipient_profile_id uuid,
  p_sender_address text,
  p_sender_message_id uuid,
  p_body text,
  p_content_type public.message_content_type default 'text',
  p_external_id text default null,
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
  v_row public.messages;
  v_row_count integer;
  v_sender_address text := public.normalize_address(p_sender_address);
begin
  if p_recipient_profile_id is null or v_sender_address = '' then
    raise exception 'recipient and sender required';
  end if;

  if p_sender_message_id is null then
    raise exception 'sender message id required';
  end if;

  if public.is_profile_disabled(p_recipient_profile_id) then
    raise exception 'profile disabled';
  end if;

  if not public.is_address_allowed_for_reception(p_recipient_profile_id, v_sender_address) then
    raise exception 'reception denied';
  end if;

  insert into public.messages (
    archive_user_id,
    author_id,
    peer_address,
    author_address,
    logical_message_id,
    external_id,
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
    null,
    v_sender_address,
    v_sender_address,
    p_sender_message_id,
    p_external_id,
    coalesce(p_body, ''),
    p_content_type,
    p_media_url,
    p_duration_seconds,
    p_media_mime,
    p_media_size_bytes,
    p_latitude,
    p_longitude
  )
  on conflict (archive_user_id, logical_message_id, peer_address) do nothing
  returning * into v_row;

  get diagnostics v_row_count = row_count;

  if v_row_count = 0 then
    select * into v_row
    from public.messages m
    where m.archive_user_id = p_recipient_profile_id
      and m.logical_message_id = p_sender_message_id
      and m.peer_address = v_sender_address;
  end if;

  return v_row;
end;
$$;

-- ---------------------------------------------------------------------------
-- list_archive_messages: hide internal fanout outbound legs from group history
-- ---------------------------------------------------------------------------

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
    and not (
      m.author_id = m.archive_user_id
      and m.peer_address is not null
      and m.original_author_id is not null
      and m.original_author_id is distinct from m.archive_user_id
      and exists (
        select 1
        from public.messages inbound
        where inbound.archive_user_id = m.archive_user_id
          and inbound.logical_message_id = m.logical_message_id
          and inbound.author_id is distinct from m.archive_user_id
      )
    )
  order by m.created_at asc
  limit greatest(coalesce(p_limit, 100), 1);
$$;

-- ---------------------------------------------------------------------------
-- list_archive_messages: hide internal fanout outbound legs from group history
-- ---------------------------------------------------------------------------

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
    and not (
      m.author_id = m.archive_user_id
      and m.peer_address is not null
      and m.original_author_id is not null
      and m.original_author_id is distinct from m.archive_user_id
      and exists (
        select 1
        from public.messages inbound
        where inbound.archive_user_id = m.archive_user_id
          and inbound.logical_message_id = m.logical_message_id
          and inbound.author_id is distinct from m.archive_user_id
      )
    )
  order by m.created_at asc
  limit greatest(coalesce(p_limit, 100), 1);
$$;
