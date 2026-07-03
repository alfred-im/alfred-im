-- Static location sharing (part 2/2): schema, RPC, inbox — requires enum value `location`.

alter table public.messages
  add column if not exists latitude double precision,
  add column if not exists longitude double precision;

alter table public.messages
  add constraint messages_location_requires_coords check (
    content_type <> 'location'
    or (
      latitude is not null
      and longitude is not null
      and latitude >= -90
      and latitude <= 90
      and longitude >= -180
      and longitude <= 180
    )
  );

-- ---------------------------------------------------------------------------
-- Preview inbox
-- ---------------------------------------------------------------------------

create or replace function public.format_location_preview()
returns text
language sql
immutable
as $$
  select '📍 Posizione';
$$;

-- ---------------------------------------------------------------------------
-- Trigger: outbox payload includes coordinates
-- ---------------------------------------------------------------------------

create or replace function public.on_message_inserted()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.protocol = 'internal' then
    update public.messages
    set delivery_status = 'delivered'
    where id = new.id
      and delivery_status = 'sent';
  elsif new.protocol in ('xmpp', 'matrix') then
    update public.messages
    set delivery_status = 'pending'
    where id = new.id;

    insert into public.outbox (message_id, protocol, payload)
    values (
      new.id,
      new.protocol,
      jsonb_build_object(
        'body', new.body,
        'content_type', new.content_type,
        'media_url', new.media_url,
        'media_mime', new.media_mime,
        'media_size_bytes', new.media_size_bytes,
        'duration_seconds', new.duration_seconds,
        'latitude', new.latitude,
        'longitude', new.longitude,
        'sender_id', new.sender_id,
        'recipient_external_address', new.recipient_external_address,
        'client_message_id', new.client_message_id
      )
    );
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: invio messaggio (coordinate opzionali)
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
  v_id uuid;
  v_row public.messages;
  v_body text := coalesce(p_body, '');
  v_media_url text := nullif(trim(coalesce(p_media_url, '')), '');
  v_media_mime text := nullif(trim(coalesce(p_media_mime, '')), '');
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

  insert into public.messages (
    sender_id,
    recipient_profile_id,
    protocol,
    body,
    client_message_id,
    delivery_status,
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
    p_recipient_profile_id,
    'internal',
    trim(v_body),
    p_client_message_id,
    'sent',
    p_content_type,
    v_media_url,
    p_duration_seconds,
    v_media_mime,
    p_media_size_bytes,
    p_latitude,
    p_longitude
  )
  returning id into v_id;

  select * into v_row from public.messages where id = v_id;
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
-- RPC: inbox (preview location)
-- ---------------------------------------------------------------------------

drop function if exists public.list_inbox();

create or replace function public.list_inbox()
returns table (
  protocol public.contact_protocol,
  display_name text,
  peer_profile_id uuid,
  peer_external_address text,
  peer_avatar_url text,
  peer_pronouns text,
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
      case
        when m.sender_id = me.uid then m.recipient_profile_id
        else m.sender_id
      end as peer_profile_id,
      m.recipient_external_address as peer_external_address,
      m.created_at,
      m.sender_id,
      m.recipient_profile_id,
      m.content_type,
      m.body,
      m.duration_seconds,
      m.delivery_status
    from public.messages m
    cross join me
    where me.uid is not null
      and m.protocol = 'internal'
      and m.recipient_profile_id is not null
      and (m.sender_id = me.uid or m.recipient_profile_id = me.uid)
      and m.marker_type is null
      and (
        trim(m.body) <> ''
        or m.content_type in ('gif', 'voice', 'location')
      )
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
    cross join me
    where d.recipient_profile_id = me.uid
      and d.delivery_status not in ('read')
    group by d.peer_profile_id
  )
  select
    l.protocol,
    coalesce(nullif(trim(p.display_name), ''), 'Contatto') as display_name,
    l.peer_profile_id,
    l.peer_external_address,
    p.avatar_url as peer_avatar_url,
    p.pronouns as peer_pronouns,
    case
      when l.content_type = 'gif' then '[GIF]'
      when l.content_type = 'voice' then public.format_voice_preview(coalesce(l.duration_seconds, 0))
      when l.content_type = 'location' then public.format_location_preview()
      else left(trim(l.body), 120)
    end as last_message_preview,
    l.last_message_at,
    coalesce(u.unread_count, 0) as unread_count
  from latest l
  left join public.profiles p on p.id = l.peer_profile_id
  left join unread u on u.peer_profile_id = l.peer_profile_id
  order by l.last_message_at desc nulls last;
$$;

grant execute on function public.list_inbox() to authenticated;
revoke all on function public.list_inbox() from anon;

-- ---------------------------------------------------------------------------
-- RPC: storico messaggi con peer
-- ---------------------------------------------------------------------------

create or replace function public.list_peer_messages(
  p_peer_profile_id uuid,
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
  where auth.uid() is not null
    and p_peer_profile_id is not null
    and m.marker_type is null
    and (
      trim(m.body) <> ''
      or m.content_type in ('gif', 'voice', 'location')
    )
    and (
      (m.sender_id = auth.uid() and m.recipient_profile_id = p_peer_profile_id)
      or (m.sender_id = p_peer_profile_id and m.recipient_profile_id = auth.uid())
    )
  order by m.created_at asc
  limit greatest(1, least(coalesce(p_limit, 100), 500));
$$;

-- ---------------------------------------------------------------------------
-- RPC: segna messaggi da peer come letti
-- ---------------------------------------------------------------------------

create or replace function public.mark_peer_read(p_peer_profile_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then
    raise exception 'not authenticated';
  end if;

  if p_peer_profile_id is null then
    raise exception 'peer required';
  end if;

  insert into public.message_read_receipts (message_id, profile_id, status)
  select m.id, v_me, 'read'::public.message_delivery_status
  from public.messages m
  where m.sender_id = p_peer_profile_id
    and m.recipient_profile_id = v_me
    and m.marker_type is null
    and (
      trim(m.body) <> ''
      or m.content_type in ('gif', 'voice', 'location')
    )
  on conflict do nothing;

  update public.messages m
  set delivery_status = 'read'
  where m.sender_id = p_peer_profile_id
    and m.recipient_profile_id = v_me
    and m.delivery_status in ('sent', 'delivered');
end;
$$;

grant execute on function public.list_peer_messages(uuid, integer) to authenticated;
grant execute on function public.mark_peer_read(uuid) to authenticated;

revoke all on function public.list_peer_messages(uuid, integer) from anon;
revoke all on function public.mark_peer_read(uuid) from anon;
