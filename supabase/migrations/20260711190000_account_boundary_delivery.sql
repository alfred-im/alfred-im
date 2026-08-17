-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- SYS-ACCOUNT-BOUNDARY + SYS-DELIVERY: delivery plane; account RPC solo confine proprio.

create schema if not exists alfred_delivery;

-- ---------------------------------------------------------------------------
-- Worker: erogate group message to allow list participants
-- ---------------------------------------------------------------------------

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
begin
  for v_participant in
    select r.allowed_profile_id
    from public.reception_allowlist r
    where r.owner_id = p_group_id
      and r.allowed_profile_id is not null
      and r.allowed_profile_id <> p_group_id
      and r.allowed_profile_id <> p_original_author_id
  loop
    if not public.is_sender_allowed_for_reception(v_participant, p_group_id) then
      continue;
    end if;

    insert into public.messages (
      owner_id,
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
    on conflict (owner_id, logical_message_id) do nothing;
  end loop;
end;
$$;

revoke all on function alfred_delivery.erogate_group_message(
  uuid, uuid, uuid, public.contact_protocol, text, public.message_content_type,
  text, integer, text, bigint, double precision, double precision
) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Worker: propagate read receipt to sender copy
-- ---------------------------------------------------------------------------

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
  where sender_copy.owner_id = p_sender_profile_id
    and sender_copy.logical_message_id = p_logical_message_id
    and sender_copy.read_at is null;
end;
$$;

revoke all on function alfred_delivery.propagate_read_receipt(uuid, uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Worker: deliver internal message (1:1 or to group archive)
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
  v_lambda uuid;
  v_content_author uuid;
begin
  select * into v_outbox from public.outbox where id = p_outbox_id for update;
  if v_outbox.id is null then
    raise exception 'outbox row not found';
  end if;

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

  v_recipient_kind := public.profile_kind_of(v_recipient_id);
  v_sender_kind := public.profile_kind_of(v_sender.owner_id);
  v_content_author := case
    when v_recipient_kind = 'group' or v_sender_kind = 'group' then v_sender.owner_id
    else null
  end;

  if v_recipient_kind = 'group' then
    v_allowed :=
      public.is_sender_allowed_for_reception(v_recipient_id, v_sender.owner_id)
      and public.is_sender_allowed_for_reception(v_sender.owner_id, v_recipient_id);

    if v_allowed then
      insert into public.messages (
        owner_id,
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
        v_recipient_id,
        v_sender.owner_id,
        v_sender.owner_id,
        v_sender.owner_id,
        v_lambda,
        coalesce(v_sender.protocol, 'internal'::public.contact_protocol),
        coalesce(v_payload ->> 'body', v_sender.body),
        coalesce((v_payload ->> 'content_type')::public.message_content_type, v_sender.content_type),
        coalesce(v_payload ->> 'media_url', v_sender.media_url),
        coalesce((v_payload ->> 'duration_seconds')::integer, v_sender.duration_seconds),
        coalesce(v_payload ->> 'media_mime', v_sender.media_mime),
        coalesce((v_payload ->> 'media_size_bytes')::bigint, v_sender.media_size_bytes),
        coalesce((v_payload ->> 'latitude')::double precision, v_sender.latitude),
        coalesce((v_payload ->> 'longitude')::double precision, v_sender.longitude)
      )
      on conflict (owner_id, logical_message_id) do nothing;

      update public.messages
      set delivered_at = now()
      where id = v_sender_id
        and delivered_at is null;

      perform alfred_delivery.erogate_group_message(
        v_recipient_id,
        v_sender.owner_id,
        v_lambda,
        coalesce(v_sender.protocol, 'internal'::public.contact_protocol),
        coalesce(v_payload ->> 'body', v_sender.body),
        coalesce((v_payload ->> 'content_type')::public.message_content_type, v_sender.content_type),
        coalesce(v_payload ->> 'media_url', v_sender.media_url),
        coalesce((v_payload ->> 'duration_seconds')::integer, v_sender.duration_seconds),
        coalesce(v_payload ->> 'media_mime', v_sender.media_mime),
        coalesce((v_payload ->> 'media_size_bytes')::bigint, v_sender.media_size_bytes),
        coalesce((v_payload ->> 'latitude')::double precision, v_sender.latitude),
        coalesce((v_payload ->> 'longitude')::double precision, v_sender.longitude)
      );

      update public.outbox
      set status = 'completed', updated_at = now()
      where id = p_outbox_id;
    else
      update public.outbox
      set
        status = 'completed',
        payload = v_payload || jsonb_build_object('reception_rejected', true),
        updated_at = now()
      where id = p_outbox_id;
    end if;
  else
    v_allowed := public.is_sender_allowed_for_reception(v_recipient_id, v_sender.owner_id);

    if v_allowed then
      insert into public.messages (
        owner_id,
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
        v_recipient_id,
        v_sender.owner_id,
        v_content_author,
        v_sender.owner_id,
        v_lambda,
        coalesce(v_sender.protocol, 'internal'::public.contact_protocol),
        coalesce(v_payload ->> 'body', v_sender.body),
        coalesce((v_payload ->> 'content_type')::public.message_content_type, v_sender.content_type),
        coalesce(v_payload ->> 'media_url', v_sender.media_url),
        coalesce((v_payload ->> 'duration_seconds')::integer, v_sender.duration_seconds),
        coalesce(v_payload ->> 'media_mime', v_sender.media_mime),
        coalesce((v_payload ->> 'media_size_bytes')::bigint, v_sender.media_size_bytes),
        coalesce((v_payload ->> 'latitude')::double precision, v_sender.latitude),
        coalesce((v_payload ->> 'longitude')::double precision, v_sender.longitude)
      )
      on conflict (owner_id, logical_message_id) do nothing;

      update public.messages
      set delivered_at = now()
      where id = v_sender_id
        and delivered_at is null;

      update public.outbox
      set status = 'completed', updated_at = now()
      where id = p_outbox_id;
    else
      update public.outbox
      set
        status = 'completed',
        payload = v_payload || jsonb_build_object('reception_rejected', true),
        updated_at = now()
      where id = p_outbox_id;
    end if;
  end if;
end;
$$;

revoke all on function alfred_delivery.deliver_internal(uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Worker: group broadcast erogation (from group archive row)
-- ---------------------------------------------------------------------------

create or replace function alfred_delivery.group_erogate(p_outbox_id uuid)
returns void
language plpgsql
security definer
set search_path = public, alfred_delivery
as $$
declare
  v_outbox public.outbox;
  v_payload jsonb;
  v_group_row public.messages;
begin
  select * into v_outbox from public.outbox where id = p_outbox_id for update;
  if v_outbox.id is null then
    raise exception 'outbox row not found';
  end if;

  if v_outbox.status = 'completed' then
    return;
  end if;

  v_payload := v_outbox.payload;

  select * into v_group_row from public.messages where id = v_outbox.message_id;
  if v_group_row.id is null then
    raise exception 'group message not found for outbox %', p_outbox_id;
  end if;

  perform alfred_delivery.erogate_group_message(
    v_group_row.owner_id,
    v_group_row.owner_id,
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

  update public.outbox
  set status = 'completed', updated_at = now()
  where id = p_outbox_id;
end;
$$;

revoke all on function alfred_delivery.group_erogate(uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Worker: read receipt outbox event
-- ---------------------------------------------------------------------------

create or replace function alfred_delivery.process_read_receipt(p_outbox_id uuid)
returns void
language plpgsql
security definer
set search_path = public, alfred_delivery
as $$
declare
  v_outbox public.outbox;
  v_payload jsonb;
  v_lambda uuid;
  v_sender_profile_id uuid;
begin
  select * into v_outbox from public.outbox where id = p_outbox_id for update;
  if v_outbox.id is null then
    raise exception 'outbox row not found';
  end if;

  if v_outbox.status = 'completed' then
    return;
  end if;

  v_payload := v_outbox.payload;
  v_lambda := (v_payload ->> 'logical_message_id')::uuid;
  v_sender_profile_id := (v_payload ->> 'sender_profile_id')::uuid;

  perform alfred_delivery.propagate_read_receipt(v_lambda, v_sender_profile_id);

  update public.outbox
  set status = 'completed', updated_at = now()
  where id = p_outbox_id;
end;
$$;

revoke all on function alfred_delivery.process_read_receipt(uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Worker: dispatcher
-- ---------------------------------------------------------------------------

create or replace function alfred_delivery.process_outbox(p_outbox_id uuid)
returns void
language plpgsql
security definer
set search_path = public, alfred_delivery
as $$
declare
  v_kind text;
begin
  select coalesce(o.payload ->> 'event_kind', 'deliver')
  into v_kind
  from public.outbox o
  where o.id = p_outbox_id;

  if v_kind = 'read_receipt' then
    perform alfred_delivery.process_read_receipt(p_outbox_id);
  elsif v_kind = 'group_erogate' then
    perform alfred_delivery.group_erogate(p_outbox_id);
  else
    perform alfred_delivery.deliver_internal(p_outbox_id);
  end if;
end;
$$;

revoke all on function alfred_delivery.process_outbox(uuid)
  from public, anon, authenticated;

-- Drop legacy public erogate (replaced by alfred_delivery)
drop function if exists public.erogate_group_message(
  uuid, uuid, uuid, public.contact_protocol, text, public.message_content_type,
  text, integer, text, bigint, double precision, double precision
);

-- ---------------------------------------------------------------------------
-- RPC: send_message_to_profile (account boundary — sender copy + outbox only)
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

  v_recipient_kind := public.profile_kind_of(p_recipient_profile_id);
  v_sender_kind := public.profile_kind_of(v_me);
  v_content_author := case
    when v_recipient_kind = 'group' or v_sender_kind = 'group' then v_me
    else null
  end;
  v_lambda := gen_random_uuid();

  insert into public.messages (
    owner_id,
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

revoke all on function public.send_message_to_profile(
  uuid, text, text, public.message_content_type, text, integer, text, bigint, double precision, double precision
) from public, anon;
grant execute on function public.send_message_to_profile(
  uuid, text, text, public.message_content_type, text, integer, text, bigint, double precision, double precision
) to authenticated;

-- ---------------------------------------------------------------------------
-- RPC: mark_peer_read (account boundary — local read + read_receipt outbox)
-- ---------------------------------------------------------------------------

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
    where m.owner_id = v_me
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

grant execute on function public.mark_peer_read(uuid) to authenticated;
revoke all on function public.mark_peer_read(uuid) from anon;

-- ---------------------------------------------------------------------------
-- RPC: broadcast_message_to_allowlist (group archive + delivery erogation)
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
    where m.owner_id = v_me
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
  where r.owner_id = v_me
    and r.allowed_profile_id is not null
    and r.allowed_profile_id <> v_me;

  if v_participant_count = 0 then
    raise exception 'no allow list recipients';
  end if;

  v_lambda := gen_random_uuid();

  insert into public.messages (
    owner_id,
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

revoke all on function public.broadcast_message_to_allowlist(
  text, text, public.message_content_type, text, integer, text, bigint, double precision, double precision
) from public, anon;
grant execute on function public.broadcast_message_to_allowlist(
  text, text, public.message_content_type, text, integer, text, bigint, double precision, double precision
) to authenticated;
