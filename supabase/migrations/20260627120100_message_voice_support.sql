-- Voice notes (part 2/2): schema, RPC, trigger, storage — requires enum value `voice`.

alter table public.messages
  add column if not exists duration_seconds integer,
  add column if not exists media_mime text,
  add column if not exists media_size_bytes bigint;

alter table public.messages
  drop constraint if exists messages_gif_requires_url;

alter table public.messages
  add constraint messages_media_requires_url check (
    content_type not in ('gif', 'voice')
    or (media_url is not null and length(trim(media_url)) > 0)
  );

alter table public.messages
  add constraint messages_voice_requires_duration check (
    content_type <> 'voice'
    or (duration_seconds is not null and duration_seconds > 0)
  );

alter table public.messages
  add constraint messages_voice_requires_mime check (
    content_type <> 'voice'
    or (media_mime is not null and length(trim(media_mime)) > 0)
  );

-- ---------------------------------------------------------------------------
-- Preview + outbox payload (voice metadata for bridge)
-- ---------------------------------------------------------------------------

create or replace function public.format_voice_preview(p_seconds integer)
returns text
language sql
immutable
as $$
  select '🎤 ' || (p_seconds / 60)::text || ':' || lpad((p_seconds % 60)::text, 2, '0');
$$;

create or replace function public.on_message_inserted()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_protocol public.contact_protocol;
  v_preview text;
begin
  select c.protocol into v_protocol
  from public.conversations c
  where c.id = new.conversation_id;

  if new.content_type = 'gif' then
    v_preview := '[GIF]';
  elsif new.content_type = 'voice' then
    v_preview := public.format_voice_preview(coalesce(new.duration_seconds, 0));
  else
    v_preview := left(trim(new.body), 120);
    if v_preview = '' and new.marker_type is not null then
      v_preview := '[stato messaggio]';
    end if;
  end if;

  update public.conversations
  set
    last_message_at = new.created_at,
    last_message_preview = v_preview,
    last_message_sender_id = new.sender_id,
    updated_at = now()
  where id = new.conversation_id;

  update public.conversation_participants
  set unread_count = unread_count + 1
  where conversation_id = new.conversation_id
    and profile_id <> new.sender_id;

  if v_protocol = 'internal' then
    update public.messages
    set delivery_status = 'delivered'
    where id = new.id
      and delivery_status = 'sent';
  elsif v_protocol in ('xmpp', 'matrix') then
    update public.messages
    set delivery_status = 'pending'
    where id = new.id;

    insert into public.outbox (message_id, conversation_id, protocol, payload)
    values (
      new.id,
      new.conversation_id,
      v_protocol,
      jsonb_build_object(
        'body', new.body,
        'content_type', new.content_type,
        'media_url', new.media_url,
        'media_mime', new.media_mime,
        'media_size_bytes', new.media_size_bytes,
        'duration_seconds', new.duration_seconds,
        'sender_id', new.sender_id,
        'client_message_id', new.client_message_id
      )
    );
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC send_message (media metadata overload)
-- ---------------------------------------------------------------------------

create or replace function public.send_message(
  p_conversation_id uuid,
  p_body text default '',
  p_client_message_id text default null,
  p_content_type public.message_content_type default 'text',
  p_media_url text default null,
  p_duration_seconds integer default null,
  p_media_mime text default null,
  p_media_size_bytes bigint default null
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

  if not public.is_conversation_participant(p_conversation_id) then
    raise exception 'not a participant';
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
  else
    raise exception 'unsupported content_type';
  end if;

  insert into public.messages (
    conversation_id,
    sender_id,
    body,
    client_message_id,
    delivery_status,
    content_type,
    media_url,
    duration_seconds,
    media_mime,
    media_size_bytes
  )
  values (
    p_conversation_id,
    v_me,
    trim(v_body),
    p_client_message_id,
    'sent',
    p_content_type,
    v_media_url,
    p_duration_seconds,
    v_media_mime,
    p_media_size_bytes
  )
  returning id into v_id;

  select * into v_row from public.messages where id = v_id;
  return v_row;
end;
$$;

create or replace function public.send_message(
  p_conversation_id uuid,
  p_body text default '',
  p_client_message_id text default null,
  p_content_type public.message_content_type default 'text',
  p_media_url text default null
)
returns public.messages
language sql
security definer
set search_path = public
as $$
  select public.send_message(
    p_conversation_id,
    p_body,
    p_client_message_id,
    p_content_type,
    p_media_url,
    null,
    null,
    null
  );
$$;

revoke all on function public.send_message(uuid, text, text, public.message_content_type, text, integer, text, bigint) from public, anon;
grant execute on function public.send_message(uuid, text, text, public.message_content_type, text, integer, text, bigint) to authenticated;

revoke all on function public.send_message(uuid, text, text, public.message_content_type, text) from public, anon;
grant execute on function public.send_message(uuid, text, text, public.message_content_type, text) to authenticated;

revoke all on function public.send_message(uuid, text, text) from public, anon;
grant execute on function public.send_message(uuid, text, text) to authenticated;

create or replace function public.mark_conversation_read(p_conversation_id uuid)
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

  if not public.is_conversation_participant(p_conversation_id) then
    raise exception 'not a participant';
  end if;

  update public.conversation_participants
  set unread_count = 0, last_read_at = now()
  where conversation_id = p_conversation_id and profile_id = v_me;

  insert into public.message_read_receipts (message_id, profile_id, status)
  select m.id, v_me, 'read'::public.message_delivery_status
  from public.messages m
  where m.conversation_id = p_conversation_id
    and m.sender_id <> v_me
    and m.marker_type is null
    and (
      trim(m.body) <> ''
      or m.content_type in ('gif', 'voice')
    )
  on conflict do nothing;

  update public.messages m
  set delivery_status = 'read'
  from public.conversation_participants cp
  where m.conversation_id = p_conversation_id
    and m.sender_id = v_me
    and cp.conversation_id = p_conversation_id
    and cp.profile_id <> v_me
    and cp.last_read_at is not null
    and m.created_at <= cp.last_read_at
    and m.delivery_status in ('sent', 'delivered');
end;
$$;

update storage.buckets
set
  file_size_limit = 15728640,
  allowed_mime_types = array['image/gif', 'audio/webm']
where id = 'chat-media';
