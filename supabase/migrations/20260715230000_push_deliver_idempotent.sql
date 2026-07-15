-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- SYS-PUSH-020: push solo su INSERT destinatario nuovo (non ON CONFLICT DO NOTHING).

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
  v_row_count integer;
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
  v_body := coalesce(v_payload ->> 'body', v_sender.body);
  v_content_type := coalesce(
    (v_payload ->> 'content_type')::public.message_content_type,
    v_sender.content_type
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
        v_body,
        v_content_type,
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
        v_sender.owner_id,
        v_lambda,
        v_content_type,
        v_body,
        v_sender.owner_id
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
        v_body,
        v_content_type,
        coalesce(v_payload ->> 'media_url', v_sender.media_url),
        coalesce((v_payload ->> 'duration_seconds')::integer, v_sender.duration_seconds),
        coalesce(v_payload ->> 'media_mime', v_sender.media_mime),
        coalesce((v_payload ->> 'media_size_bytes')::bigint, v_sender.media_size_bytes),
        coalesce((v_payload ->> 'latitude')::double precision, v_sender.latitude),
        coalesce((v_payload ->> 'longitude')::double precision, v_sender.longitude)
      )
      on conflict (owner_id, logical_message_id) do nothing;

      get diagnostics v_row_count = row_count;

      update public.messages
      set delivered_at = now()
      where id = v_sender_id
        and delivered_at is null;

      if v_row_count > 0 then
        perform alfred_delivery.queue_push_after_delivery(
          v_recipient_id,
          v_sender.owner_id,
          v_lambda,
          v_content_type,
          v_body,
          v_content_author
        );
      end if;

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
