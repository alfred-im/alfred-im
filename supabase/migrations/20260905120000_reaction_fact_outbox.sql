-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- Reactions: account RPC accoda outbox (event_kind = reaction_fact); worker INSERT fact.
-- Enables federation bus (same pattern as read_receipt / deliver).

-- ---------------------------------------------------------------------------
-- Worker: persist reaction fact from outbox
-- ---------------------------------------------------------------------------

create or replace function alfred_delivery.process_reaction_fact(p_outbox_id uuid)
returns void
language plpgsql
security definer
set search_path = public, alfred_delivery
as $$
declare
  v_outbox public.outbox;
  v_payload jsonb;
  v_lambda uuid;
  v_reactor_id uuid;
  v_kind public.message_reaction_kind;
  v_emoji text;
  v_latest public.message_reaction_facts;
  v_row public.message_reaction_facts;
begin
  v_outbox := alfred_delivery._claim_outbox(p_outbox_id);
  if v_outbox.status = 'completed' then
    return;
  end if;

  v_payload := v_outbox.payload;
  v_lambda := (v_payload ->> 'logical_message_id')::uuid;
  v_reactor_id := (v_payload ->> 'reactor_id')::uuid;
  v_kind := (v_payload ->> 'kind')::public.message_reaction_kind;
  v_emoji := nullif(trim(coalesce(v_payload ->> 'emoji', '')), '');

  if v_lambda is null or v_reactor_id is null or v_kind is null then
    raise exception 'reaction_fact outbox payload incomplete';
  end if;

  if v_kind = 'applied' and v_emoji is null then
    raise exception 'reaction_fact applied requires emoji';
  end if;

  if v_kind = 'withdrawn' and v_emoji is not null then
    raise exception 'reaction_fact withdrawn must not carry emoji';
  end if;

  if not public.mailbox_is_message_participant(v_lambda, v_reactor_id) then
    raise exception 'not a message participant';
  end if;

  v_latest := public.message_reaction_latest_fact(v_lambda, v_reactor_id);

  if v_kind = 'applied' then
    if v_latest.id is not null
      and v_latest.kind = 'applied'
      and v_latest.emoji = v_emoji then
      perform alfred_delivery._complete_outbox(
        p_outbox_id,
        v_payload || jsonb_build_object('reaction_fact_id', v_latest.id)
      );
      return;
    end if;

    insert into public.message_reaction_facts (
      logical_message_id,
      reactor_id,
      kind,
      emoji,
      occurred_at
    )
    values (
      v_lambda,
      v_reactor_id,
      'applied',
      v_emoji,
      clock_timestamp()
    )
    returning * into v_row;
  else
    if v_latest.id is null or v_latest.kind = 'withdrawn' then
      perform alfred_delivery._complete_outbox(p_outbox_id, v_payload);
      return;
    end if;

    insert into public.message_reaction_facts (
      logical_message_id,
      reactor_id,
      kind,
      emoji,
      occurred_at
    )
    values (
      v_lambda,
      v_reactor_id,
      'withdrawn',
      null,
      clock_timestamp()
    )
    returning * into v_row;
  end if;

  perform alfred_delivery._complete_outbox(
    p_outbox_id,
    v_payload || jsonb_build_object('reaction_fact_id', v_row.id)
  );
end;
$$;

revoke all on function alfred_delivery.process_reaction_fact(uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Dispatcher
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
  elsif v_kind = 'push_notify' then
    perform alfred_delivery.process_push_notify(p_outbox_id);
  elsif v_kind = 'reaction_fact' then
    perform alfred_delivery.process_reaction_fact(p_outbox_id);
  else
    perform alfred_delivery.deliver_internal(p_outbox_id);
  end if;
end;
$$;

revoke all on function alfred_delivery.process_outbox(uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- RPC: apply / withdraw — accoda outbox, worker persiste il fatto
-- ---------------------------------------------------------------------------

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

  insert into public.outbox (message_id, protocol, payload, status)
  values (v_anchor_id, 'internal', v_payload, 'queued')
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

  if not public.mailbox_is_message_participant(p_logical_message_id, v_me) then
    raise exception 'not a message participant';
  end if;

  v_latest := public.message_reaction_latest_fact(p_logical_message_id, v_me);

  if v_latest.id is null or v_latest.kind = 'withdrawn' then
    return null;
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

  insert into public.outbox (message_id, protocol, payload, status)
  values (v_anchor_id, 'internal', v_payload, 'queued')
  returning id into v_outbox_id;

  perform alfred_delivery.process_outbox(v_outbox_id);

  select * into v_latest
  from public.message_reaction_latest_fact(p_logical_message_id, v_me);

  return v_latest;
end;
$$;

grant execute on function public.apply_message_reaction(uuid, text) to authenticated;
revoke all on function public.apply_message_reaction(uuid, text) from anon;

grant execute on function public.withdraw_message_reaction(uuid) to authenticated;
revoke all on function public.withdraw_message_reaction(uuid) from anon;
