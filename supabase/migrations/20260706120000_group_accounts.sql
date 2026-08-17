-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- GROUP-CORE + GROUP-DELIVERY: profile_kind, original_author_id, group send/erogation.

-- ---------------------------------------------------------------------------
-- Enum + schema
-- ---------------------------------------------------------------------------

create type public.profile_kind as enum ('user', 'group');

alter table public.profiles
  add column if not exists profile_kind public.profile_kind not null default 'user';

alter table public.messages
  add column if not exists original_author_id uuid references public.profiles (id);

create index if not exists messages_original_author_id_idx
  on public.messages (original_author_id)
  where original_author_id is not null;

-- ---------------------------------------------------------------------------
-- Auth trigger: profile_kind from user_metadata
-- ---------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_username text;
  v_display_name text;
  v_kind public.profile_kind := 'user';
  v_kind_raw text;
begin
  v_username := lower(new.raw_user_meta_data ->> 'username');
  v_username := regexp_replace(coalesce(v_username, ''), '[^a-z0-9_]', '_', 'g');

  if length(v_username) < 3 then
    v_username := 'user_' || substr(replace(new.id::text, '-', ''), 1, 8);
  end if;

  v_display_name := coalesce(
    new.raw_user_meta_data ->> 'display_name',
    initcap(replace(v_username, '_', ' '))
  );

  v_kind_raw := lower(coalesce(new.raw_user_meta_data ->> 'profile_kind', ''));
  if v_kind_raw = 'group' then
    v_kind := 'group';
  end if;

  insert into public.profiles (id, username, display_name, profile_kind)
  values (new.id, v_username, v_display_name, v_kind)
  on conflict (id) do nothing;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public.is_bidirectional_allowed(
  p_owner_a uuid,
  p_owner_b uuid,
  p_sender uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_sender_allowed_for_reception(p_owner_a, p_sender)
     and public.is_sender_allowed_for_reception(p_owner_b, p_sender);
$$;

revoke all on function public.is_bidirectional_allowed(uuid, uuid, uuid) from public, anon;
grant execute on function public.is_bidirectional_allowed(uuid, uuid, uuid) to authenticated;

create or replace function public.profile_kind_of(p_profile_id uuid)
returns public.profile_kind
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select p.profile_kind from public.profiles p where p.id = p_profile_id),
    'user'::public.profile_kind
  );
$$;

revoke all on function public.profile_kind_of(uuid) from public, anon;
grant execute on function public.profile_kind_of(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Internal: erogate group message to allow list (after group received λ)
-- ---------------------------------------------------------------------------

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

revoke all on function public.erogate_group_message(
  uuid, uuid, uuid, public.contact_protocol, text, public.message_content_type,
  text, integer, text, bigint, double precision, double precision
) from public, anon;

-- ---------------------------------------------------------------------------
-- RPC: send (extended for group recipient + erogation)
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
    null,
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
        null,
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
        null,
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
-- RPC: group broadcast to own allow list
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
  v_participant uuid;
  v_last public.messages;
begin
  if v_me is null then
    raise exception 'not authenticated';
  end if;

  v_kind := public.profile_kind_of(v_me);
  if v_kind <> 'group' then
    raise exception 'only group accounts can broadcast';
  end if;

  for v_participant in
    select r.allowed_profile_id
    from public.reception_allowlist r
    where r.owner_id = v_me
      and r.allowed_profile_id <> v_me
  loop
    select * into v_last from public.send_message_to_profile(
      v_participant,
      p_body,
      case
        when p_client_message_id is null then null
        else p_client_message_id || ':' || v_participant::text
      end,
      p_content_type,
      p_media_url,
      p_duration_seconds,
      p_media_mime,
      p_media_size_bytes,
      p_latitude,
      p_longitude
    );
  end loop;

  if v_last is null then
    raise exception 'no allow list recipients';
  end if;

  return v_last;
end;
$$;

revoke all on function public.broadcast_message_to_allowlist(
  text, text, public.message_content_type, text, integer, text, bigint, double precision, double precision
) from public, anon;
grant execute on function public.broadcast_message_to_allowlist(
  text, text, public.message_content_type, text, integer, text, bigint, double precision, double precision
) to authenticated;

-- ---------------------------------------------------------------------------
-- RPC: owner message list (group shell)
-- ---------------------------------------------------------------------------

create or replace function public.list_owner_messages(
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
  where m.owner_id = auth.uid()
    and public.mailbox_has_renderable_content(m.body, m.content_type)
  order by m.created_at asc
  limit greatest(coalesce(p_limit, 100), 1);
$$;

revoke all on function public.list_owner_messages(integer) from public, anon;
grant execute on function public.list_owner_messages(integer) to authenticated;

-- ---------------------------------------------------------------------------
-- RPC: find profile (+ profile_kind)
-- ---------------------------------------------------------------------------

drop function if exists public.find_profile_by_username(text);

create or replace function public.find_profile_by_username(p_username text)
returns table (
  id uuid,
  username text,
  display_name text,
  avatar_url text,
  pronouns text,
  profile_kind public.profile_kind
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.username,
    p.display_name,
    p.avatar_url,
    p.pronouns,
    p.profile_kind
  from public.profiles p
  where auth.uid() is not null
    and p.id <> auth.uid()
    and lower(p.username) = lower(trim(p_username))
  limit 1;
$$;

grant execute on function public.find_profile_by_username(text) to authenticated;
revoke all on function public.find_profile_by_username(text) from public, anon;
