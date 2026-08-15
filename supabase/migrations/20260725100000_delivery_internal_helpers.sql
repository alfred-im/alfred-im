-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- DRY: shared outbox claim/complete + recipient insert helpers for alfred_delivery workers.
-- Behavior 1:1 with 20260715230000 (deliver_internal ground truth).

-- ---------------------------------------------------------------------------
-- is_bidirectional_allowed: cross-direction gate between two mailbox archive users
-- (p_sender retained for signature stability; unused)
-- ---------------------------------------------------------------------------

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

-- ---------------------------------------------------------------------------
-- Internal helpers (alfred_delivery schema)
-- ---------------------------------------------------------------------------

create or replace function alfred_delivery._claim_outbox(p_outbox_id uuid)
returns public.outbox
language plpgsql
security definer
set search_path = public, alfred_delivery
as $$
declare
  v_outbox public.outbox;
begin
  select * into v_outbox from public.outbox where id = p_outbox_id for update;
  if v_outbox.id is null then
    raise exception 'outbox row not found';
  end if;
  return v_outbox;
end;
$$;

create or replace function alfred_delivery._complete_outbox(
  p_outbox_id uuid,
  p_payload jsonb default null
)
returns void
language plpgsql
security definer
set search_path = public, alfred_delivery
as $$
begin
  if p_payload is not null then
    update public.outbox
    set
      status = 'completed',
      payload = p_payload,
      updated_at = now()
    where id = p_outbox_id;
  else
    update public.outbox
    set status = 'completed', updated_at = now()
    where id = p_outbox_id;
  end if;
end;
$$;

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

revoke all on function alfred_delivery._claim_outbox(uuid)
  from public, anon, authenticated;
revoke all on function alfred_delivery._complete_outbox(uuid, jsonb)
  from public, anon, authenticated;
revoke all on function alfred_delivery._insert_recipient_copy(
  uuid, uuid, uuid, uuid, uuid, public.contact_protocol, text,
  public.message_content_type, jsonb, public.messages
) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- deliver_internal: collapsed group/1:1 with shared helpers
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

revoke all on function alfred_delivery.deliver_internal(uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- process_read_receipt, group_erogate, process_push_notify: _claim/_complete
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
begin
  v_outbox := alfred_delivery._claim_outbox(p_outbox_id);
  if v_outbox.status = 'completed' then
    return;
  end if;

  v_payload := v_outbox.payload;

  perform alfred_delivery.propagate_read_receipt(
    (v_payload ->> 'logical_message_id')::uuid,
    (v_payload ->> 'sender_profile_id')::uuid
  );

  perform alfred_delivery._complete_outbox(p_outbox_id);
end;
$$;

revoke all on function alfred_delivery.process_read_receipt(uuid)
  from public, anon, authenticated;

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

revoke all on function alfred_delivery.group_erogate(uuid)
  from public, anon, authenticated;

create or replace function alfred_delivery.process_push_notify(p_outbox_id uuid)
returns void
language plpgsql
security definer
set search_path = public, alfred_delivery, extensions
as $$
declare
  v_outbox public.outbox;
  v_payload jsonb;
  v_settings alfred_delivery.push_settings;
  v_url text;
  v_headers jsonb;
begin
  v_outbox := alfred_delivery._claim_outbox(p_outbox_id);
  if v_outbox.status = 'completed' then
    return;
  end if;

  v_payload := v_outbox.payload;

  select * into v_settings from alfred_delivery.push_settings where singleton is true;

  if coalesce(v_settings.enabled, false) then
    v_url := rtrim(v_settings.functions_base_url, '/') || '/send-push';
    v_headers := jsonb_build_object('Content-Type', 'application/json');
    if v_settings.dispatch_secret is not null and length(trim(v_settings.dispatch_secret)) > 0 then
      v_headers := v_headers || jsonb_build_object('X-Push-Dispatch-Secret', v_settings.dispatch_secret);
    end if;

    perform net.http_post(
      url := v_url,
      headers := v_headers,
      body := v_payload
    );
  end if;

  perform alfred_delivery._complete_outbox(p_outbox_id);
end;
$$;

revoke all on function alfred_delivery.process_push_notify(uuid)
  from public, anon, authenticated;
