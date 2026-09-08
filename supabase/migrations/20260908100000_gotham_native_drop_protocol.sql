-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- Gotham-only: remove legacy XMPP/Matrix bridge tables and contact_protocol enum.
-- Routing is implicit: peer_profile_id = same instance; peer_external_address = federated.

-- ---------------------------------------------------------------------------
-- Legacy bridge infrastructure (removed)
-- ---------------------------------------------------------------------------

drop table if exists public.bridge_jobs cascade;
drop table if exists public.sync_cursors cascade;

-- ---------------------------------------------------------------------------
-- Drop functions whose signatures reference contact_protocol
-- ---------------------------------------------------------------------------

drop function if exists alfred_delivery.erogate_group_message(
  uuid, uuid, uuid, public.contact_protocol, text, public.message_content_type,
  text, integer, text, bigint, double precision, double precision
);

drop function if exists alfred_delivery._insert_recipient_copy(
  uuid, uuid, uuid, uuid, uuid, public.contact_protocol, text,
  public.message_content_type, jsonb, public.messages
);

drop function if exists alfred_delivery.materialize_inbound_sender_message(
  uuid, uuid, uuid, public.contact_protocol, text, public.message_content_type,
  text, text, integer, text, bigint, double precision, double precision
);

drop function if exists public.erogate_group_message(
  uuid, uuid, uuid, public.contact_protocol, text, public.message_content_type,
  text, integer, text, bigint, double precision, double precision
);

drop function if exists public.list_inbox();

-- ---------------------------------------------------------------------------
-- Delivery helpers (no protocol column)
-- ---------------------------------------------------------------------------

create or replace function alfred_delivery._insert_recipient_copy(
  p_recipient_id uuid,
  p_author_id uuid,
  p_original_author_id uuid,
  p_peer_profile_id uuid,
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
    peer_profile_id,
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
    p_peer_profile_id,
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
  on conflict (archive_user_id, logical_message_id) do nothing;

  get diagnostics v_row_count = row_count;
  return v_row_count;
end;
$$;

create or replace function alfred_delivery.materialize_inbound_sender_message(
  p_recipient_profile_id uuid,
  p_sender_profile_id uuid,
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
begin
  if p_recipient_profile_id is null or p_sender_profile_id is null then
    raise exception 'recipient and sender required';
  end if;

  if p_sender_message_id is null then
    raise exception 'sender message id required';
  end if;

  if public.is_profile_disabled(p_recipient_profile_id)
     or public.is_profile_disabled(p_sender_profile_id) then
    raise exception 'profile disabled';
  end if;

  if not public.is_sender_allowed_for_reception(p_recipient_profile_id, p_sender_profile_id) then
    raise exception 'reception denied';
  end if;

  insert into public.messages (
    archive_user_id,
    author_id,
    peer_profile_id,
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
    p_sender_profile_id,
    p_sender_profile_id,
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
  on conflict (archive_user_id, logical_message_id) do nothing
  returning * into v_row;

  get diagnostics v_row_count = row_count;

  if v_row_count = 0 then
    select * into v_row
    from public.messages m
    where m.archive_user_id = p_recipient_profile_id
      and m.logical_message_id = p_sender_message_id;
  end if;

  return v_row;
end;
$$;

revoke all on function alfred_delivery.materialize_inbound_sender_message(
  uuid, uuid, uuid, text, public.message_content_type,
  text, text, integer, text, bigint, double precision, double precision
) from public, anon, authenticated;
grant execute on function alfred_delivery.materialize_inbound_sender_message(
  uuid, uuid, uuid, text, public.message_content_type,
  text, text, integer, text, bigint, double precision, double precision
) to service_role;

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

revoke all on function alfred_delivery.erogate_group_message(
  uuid, uuid, uuid, text, public.message_content_type,
  text, integer, text, bigint, double precision, double precision
) from public, anon, authenticated;

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

  if public.is_profile_disabled(v_sender.archive_user_id)
     or public.is_profile_disabled(v_recipient_id) then
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
        coalesce((v_payload ->> 'longitude')::double precision, v_sender.longitude)
      );

      perform alfred_delivery.queue_push_after_delivery(
        v_recipient_id,
        v_sender.archive_user_id,
        v_sender_message_id,
        v_content_type,
        v_body,
        v_sender.archive_user_id
      );
    elsif v_row_count > 0 then
      perform alfred_delivery.queue_push_after_delivery(
        v_recipient_id,
        v_sender.archive_user_id,
        v_sender_message_id,
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
    v_group_row.longitude
  );

  perform alfred_delivery._complete_outbox(p_outbox_id);
end;
$$;

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
  v_icon_url text;
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

  select nullif(trim(c.value ->> 'logo_url'), '')
  into v_icon_url
  from public.instance_config c
  where c.key = 'instance.branding';

  v_payload := jsonb_build_object(
    'event_kind', 'push_notify',
    'recipient_user_id', p_recipient_user_id,
    'recipient_display_name', coalesce(v_recipient_name, 'Alfred'),
    'recipient_username', v_recipient_username,
    'peer_profile_id', p_peer_profile_id,
    'peer_display_name', coalesce(v_peer_name, 'Alfred'),
    'preview_text', v_preview,
    'logical_message_id', p_logical_message_id,
    'content_type', p_content_type::text,
    'icon_url', v_icon_url
  );

  insert into public.outbox (message_id, payload, status)
  values (v_recipient_message_id, v_payload, 'queued')
  returning id into v_outbox_id;

  perform alfred_delivery.process_push_notify(v_outbox_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: send / broadcast — outbox without protocol column
-- (Bodies copied from 20260905000000; only protocol references removed.)
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
  v_sender_message_id uuid;
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

  perform public.assert_profile_active(v_me);

  if p_recipient_profile_id is null then
    raise exception 'recipient required';
  end if;

  if p_recipient_profile_id = v_me then
    raise exception 'cannot message yourself';
  end if;

  if not exists (select 1 from public.profiles where id = p_recipient_profile_id) then
    raise exception 'recipient not found';
  end if;

  perform public.assert_profile_active(p_recipient_profile_id);

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

  v_sender_message_id := gen_random_uuid();

  insert into public.messages (
    archive_user_id,
    author_id,
    original_author_id,
    peer_profile_id,
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
    v_content_author,
    p_recipient_profile_id,
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
  returning id into v_sender_id;

  v_outbox_payload := jsonb_build_object(
    'event_kind', 'deliver',
    'logical_message_id', v_sender_message_id,
    'sender_id', v_me,
    'recipient_profile_id', p_recipient_profile_id,
    'body', trim(v_body),
    'content_type', p_content_type,
    'media_url', v_media_url,
    'media_mime', v_media_mime,
    'media_size_bytes', p_media_size_bytes,
    'duration_seconds', p_duration_seconds,
    'latitude', p_latitude,
    'longitude', p_longitude
  );

  insert into public.outbox (message_id, payload, status)
  values (v_sender_id, v_outbox_payload, 'queued')
  returning id into v_outbox_id;

  perform alfred_delivery.process_outbox(v_outbox_id);

  select * into v_row from public.messages where id = v_sender_id;
  return v_row;
end;
$$;

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
    and r.allowed_profile_id is not null
    and r.allowed_profile_id <> v_me;

  if v_participant_count = 0 then
    raise exception 'no allow list recipients';
  end if;

  v_sender_message_id := gen_random_uuid();

  insert into public.messages (
    archive_user_id,
    author_id,
    original_author_id,
    peer_profile_id,
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
    null,
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
  v_read_receipt_id uuid;
  v_outbox_id uuid;
begin
  if v_me is null then
    raise exception 'not authenticated';
  end if;

  if p_peer_profile_id is null then
    raise exception 'peer required';
  end if;

  for v_lambda, v_incoming_id, v_read_receipt_id in
    update public.messages m
    set
      read_at = now(),
      read_receipt_id = gen_random_uuid()
    where m.archive_user_id = v_me
      and m.peer_profile_id = p_peer_profile_id
      and m.author_id = p_peer_profile_id
      and m.read_at is null
      and public.mailbox_has_renderable_content(m.body, m.content_type)
    returning m.logical_message_id, m.id, m.read_receipt_id
  loop
    insert into public.outbox (message_id, payload, status)
    values (
      v_incoming_id,
      jsonb_build_object(
        'event_kind', 'read_receipt',
        'logical_message_id', v_lambda,
        'read_receipt_id', v_read_receipt_id,
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

create or replace function public.apply_message_reaction(
  p_logical_message_id uuid,
  p_emoji text
)
returns public.message_reaction_facts
language plpgsql
security definer
set search_path = public, alfred_delivery
as $$
declare
  v_me uuid := auth.uid();
  v_emoji text := nullif(trim(coalesce(p_emoji, '')), '');
  v_latest public.message_reaction_facts;
  v_anchor_id uuid;
  v_outbox_id uuid;
  v_payload jsonb;
begin
  if v_me is null then
    raise exception 'not authenticated';
  end if;

  if p_logical_message_id is null then
    raise exception 'logical_message_id required';
  end if;

  if v_emoji is null then
    raise exception 'emoji required';
  end if;

  if char_length(v_emoji) > 32 then
    raise exception 'emoji too long';
  end if;

  if not public.mailbox_is_message_participant(p_logical_message_id, v_me) then
    raise exception 'not a message participant';
  end if;

  v_latest := public.message_reaction_latest_fact(p_logical_message_id, v_me);

  if v_latest.id is not null
    and v_latest.kind = 'applied'
    and v_latest.emoji = v_emoji then
    return v_latest;
  end if;

  select m.id into v_anchor_id
  from public.messages m
  where m.archive_user_id = v_me
    and m.logical_message_id = p_logical_message_id
  limit 1;

  if v_anchor_id is null then
    raise exception 'message anchor not found';
  end if;

  v_payload := jsonb_build_object(
    'event_kind', 'reaction_fact',
    'logical_message_id', p_logical_message_id,
    'reactor_id', v_me,
    'kind', 'applied',
    'emoji', v_emoji
  );

  insert into public.outbox (message_id, payload, status)
  values (v_anchor_id, v_payload, 'queued')
  returning id into v_outbox_id;

  perform alfred_delivery.process_outbox(v_outbox_id);

  select * into v_latest
  from public.message_reaction_latest_fact(p_logical_message_id, v_me);

  return v_latest;
end;
$$;

create or replace function public.withdraw_message_reaction(
  p_logical_message_id uuid
)
returns public.message_reaction_facts
language plpgsql
security definer
set search_path = public, alfred_delivery
as $$
declare
  v_me uuid := auth.uid();
  v_latest public.message_reaction_facts;
  v_anchor_id uuid;
  v_outbox_id uuid;
  v_payload jsonb;
begin
  if v_me is null then
    raise exception 'not authenticated';
  end if;

  if p_logical_message_id is null then
    raise exception 'logical_message_id required';
  end if;

  v_latest := public.message_reaction_latest_fact(p_logical_message_id, v_me);

  if v_latest.id is null or v_latest.kind = 'withdrawn' then
    return v_latest;
  end if;

  select m.id into v_anchor_id
  from public.messages m
  where m.archive_user_id = v_me
    and m.logical_message_id = p_logical_message_id
  limit 1;

  if v_anchor_id is null then
    raise exception 'message anchor not found';
  end if;

  v_payload := jsonb_build_object(
    'event_kind', 'reaction_fact',
    'logical_message_id', p_logical_message_id,
    'reactor_id', v_me,
    'kind', 'withdrawn'
  );

  insert into public.outbox (message_id, payload, status)
  values (v_anchor_id, v_payload, 'queued')
  returning id into v_outbox_id;

  perform alfred_delivery.process_outbox(v_outbox_id);

  select * into v_latest
  from public.message_reaction_latest_fact(p_logical_message_id, v_me);

  return v_latest;
end;
$$;

-- ---------------------------------------------------------------------------
-- list_inbox + peer_relationship (no protocol column)
-- ---------------------------------------------------------------------------

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

create or replace function public.list_inbox()
returns table (
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
      and m.peer_profile_id is not null
      and public.mailbox_has_renderable_content(m.body, m.content_type)
  ),
  latest as (
    select distinct on (d.peer_profile_id)
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

grant execute on function public.list_inbox() to authenticated;
revoke all on function public.list_inbox() from anon;

-- ---------------------------------------------------------------------------
-- Drop protocol columns and enum
-- ---------------------------------------------------------------------------

alter table public.contacts drop constraint if exists contacts_protocol_shape;
alter table public.contacts drop constraint if exists contacts_internal_requires_profile;

alter table public.contacts drop column if exists protocol;
alter table public.messages drop column if exists protocol;
alter table public.outbox drop column if exists protocol;

drop type if exists public.contact_protocol;

alter table public.contacts
  add constraint contacts_shape check (
    (
      linked_profile_id is not null
      and external_address is null
    )
    or (
      external_address is not null
      and linked_profile_id is null
    )
  );

comment on column public.messages.peer_profile_id is
  'Controparte sulla stessa istanza; null se peer_external_address è valorizzato (federato).';

comment on column public.messages.peer_external_address is
  'Indirizzo federato user@server (Gotham); null se peer_profile_id è valorizzato (stessa istanza).';

comment on column public.contacts.linked_profile_id is
  'Profilo Alfred locale; null se il contatto è salvato solo come external_address federato.';

comment on column public.contacts.external_address is
  'Indirizzo Alfred federato user@server; null se linked_profile_id è valorizzato.';
