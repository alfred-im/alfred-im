-- Spunte cloud: per chat interna, "consegnato" = ricevuto sul server (fonte di verità).
-- Vedi docs/decisions/server-as-reception.md

-- ---------------------------------------------------------------------------
-- Trigger: promuove a delivered dopo insert su conversazioni internal
-- ---------------------------------------------------------------------------

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
        'sender_id', new.sender_id,
        'client_message_id', new.client_message_id
      )
    );
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC send_message: ritorna riga post-trigger (delivery_status aggiornato)
-- ---------------------------------------------------------------------------

create or replace function public.send_message(
  p_conversation_id uuid,
  p_body text default '',
  p_client_message_id text default null,
  p_content_type public.message_content_type default 'text',
  p_media_url text default null
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
    media_url
  )
  values (
    p_conversation_id,
    v_me,
    trim(v_body),
    p_client_message_id,
    'sent',
    p_content_type,
    v_media_url
  )
  returning id into v_id;

  select * into v_row from public.messages where id = v_id;
  return v_row;
end;
$$;

-- Backfill: messaggi interni già sul server ma ancora a sent
update public.messages m
set delivery_status = 'delivered'
from public.conversations c
where m.conversation_id = c.id
  and c.protocol = 'internal'
  and m.delivery_status = 'sent'
  and m.marker_type is null;
