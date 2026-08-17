-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- GROUP-DELIVERY v2: single broadcast row + original_author_id always set in group flows.

-- ---------------------------------------------------------------------------
-- send_message_to_profile (group content author + group→user originals)
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
  v_allowed boolean;
  v_recipient_kind public.profile_kind;
  v_sender_kind public.profile_kind;
  v_content_author uuid;
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

  if v_recipient_kind = 'group' then
    v_allowed :=
      public.is_sender_allowed_for_reception(p_recipient_profile_id, v_me)
      and public.is_sender_allowed_for_reception(v_me, p_recipient_profile_id);

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
        p_recipient_profile_id,
        v_me,
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

      perform public.erogate_group_message(
        p_recipient_profile_id,
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

      insert into public.outbox (message_id, protocol, payload, status)
      values (v_sender_id, 'internal', v_outbox_payload, 'completed');
    else
      insert into public.outbox (message_id, protocol, payload, status)
      values (
        v_sender_id,
        'internal',
        v_outbox_payload || jsonb_build_object('reception_rejected', true),
        'completed'
      );
    end if;
  else
    v_allowed := public.is_sender_allowed_for_reception(p_recipient_profile_id, v_me);

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
        p_recipient_profile_id,
        v_me,
        v_content_author,
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

      insert into public.outbox (message_id, protocol, payload, status)
      values (v_sender_id, 'internal', v_outbox_payload, 'completed');
    else
      insert into public.outbox (message_id, protocol, payload, status)
      values (
        v_sender_id,
        'internal',
        v_outbox_payload || jsonb_build_object('reception_rejected', true),
        'completed'
      );
    end if;
  end if;

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
-- broadcast: one group archive row + proxy distribution (same λ)
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
set search_path = public
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
  v_outbox_payload jsonb;
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

  perform public.erogate_group_message(
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

  v_outbox_payload := jsonb_build_object(
    'logical_message_id', v_lambda,
    'sender_id', v_me,
    'broadcast', true,
    'body', trim(v_body),
    'content_type', p_content_type,
    'client_message_id', p_client_message_id
  );

  insert into public.outbox (message_id, protocol, payload, status)
  values (v_row.id, 'internal', v_outbox_payload, 'completed');

  return v_row;
end;
$$;

revoke all on function public.broadcast_message_to_allowlist(
  text, text, public.message_content_type, text, integer, text, bigint, double precision, double precision
) from public, anon;
grant execute on function public.broadcast_message_to_allowlist(
  text, text, public.message_content_type, text, integer, text, bigint, double precision, double precision
) to authenticated;
