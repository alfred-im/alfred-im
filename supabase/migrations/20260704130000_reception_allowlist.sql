-- RECEPTION-ALLOWLIST: personal reception allow list + gate in send_message_to_profile.

-- ---------------------------------------------------------------------------
-- Table
-- ---------------------------------------------------------------------------

create table public.reception_allowlist (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  allowed_profile_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint reception_allowlist_not_self check (allowed_profile_id <> owner_id),
  constraint reception_allowlist_owner_allowed_unique unique (owner_id, allowed_profile_id)
);

create index reception_allowlist_owner_id_idx on public.reception_allowlist (owner_id);

alter table public.reception_allowlist enable row level security;

create policy reception_allowlist_select_own
  on public.reception_allowlist for select to authenticated
  using (owner_id = auth.uid());

create policy reception_allowlist_insert_own
  on public.reception_allowlist for insert to authenticated
  with check (
    owner_id = auth.uid()
    and allowed_profile_id <> auth.uid()
  );

create policy reception_allowlist_delete_own
  on public.reception_allowlist for delete to authenticated
  using (owner_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Gate helper (used by send RPC and future bridge consumers)
-- ---------------------------------------------------------------------------

create or replace function public.is_sender_allowed_for_reception(
  p_owner_id uuid,
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
    where r.owner_id = p_owner_id
      and r.allowed_profile_id = p_sender_profile_id
  );
$$;

revoke all on function public.is_sender_allowed_for_reception(uuid, uuid) from public, anon;
grant execute on function public.is_sender_allowed_for_reception(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- RPC: send (outbox always + conditional internal delivery)
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

  v_allowed := public.is_sender_allowed_for_reception(p_recipient_profile_id, v_me);

  if v_allowed then
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
