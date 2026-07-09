-- Alfred — schema dominio (piattaforma)
-- Client Flutter parla solo con Supabase; bridge leggono outbox/sync (service_role).

-- ---------------------------------------------------------------------------
-- Tipi
-- ---------------------------------------------------------------------------

create type public.contact_protocol as enum ('internal', 'xmpp', 'matrix');

create type public.message_delivery_status as enum (
  'pending',
  'sent',
  'delivered',
  'read',
  'failed'
);

create type public.queue_status as enum (
  'queued',
  'processing',
  'completed',
  'failed'
);

-- ---------------------------------------------------------------------------
-- Profili (identità Alfred — 1:1 con auth.users)
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null,
  display_name text not null,
  bio text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_username_format check (username ~ '^[a-z0-9_]{3,32}$')
);

create unique index profiles_username_lower_idx on public.profiles (lower(username));

-- ---------------------------------------------------------------------------
-- Contatti (rubrica unificata — protocollo solo per routing interno)
-- ---------------------------------------------------------------------------

create table public.contacts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  protocol public.contact_protocol not null default 'internal',
  linked_profile_id uuid references public.profiles (id) on delete set null,
  external_address text,
  display_name text not null,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint contacts_internal_requires_profile check (
    (protocol = 'internal' and linked_profile_id is not null and external_address is null)
    or (protocol in ('xmpp', 'matrix') and external_address is not null)
  )
);

create unique index contacts_owner_linked_profile_idx
  on public.contacts (owner_id, linked_profile_id)
  where linked_profile_id is not null;

create unique index contacts_owner_external_address_idx
  on public.contacts (owner_id, lower(external_address))
  where external_address is not null;

create index contacts_owner_id_idx on public.contacts (owner_id);

-- ---------------------------------------------------------------------------
-- Conversazioni e partecipanti
-- ---------------------------------------------------------------------------

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  protocol public.contact_protocol not null,
  is_group boolean not null default false,
  title text,
  last_message_at timestamptz,
  last_message_preview text,
  last_message_sender_id uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.conversation_participants (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  contact_id uuid references public.contacts (id) on delete set null,
  unread_count integer not null default 0,
  last_read_at timestamptz,
  joined_at timestamptz not null default now(),
  unique (conversation_id, profile_id)
);

create index conversation_participants_profile_id_idx
  on public.conversation_participants (profile_id);

create index conversations_last_message_at_idx
  on public.conversations (last_message_at desc nulls last);

-- ---------------------------------------------------------------------------
-- Messaggi e ricevute di lettura
-- ---------------------------------------------------------------------------

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_id uuid not null references public.profiles (id),
  body text not null default '',
  delivery_status public.message_delivery_status not null default 'sent',
  client_message_id text,
  external_id text,
  marker_type text check (marker_type in ('receipt', 'displayed')),
  marker_for uuid references public.messages (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (conversation_id, client_message_id)
);

create index messages_conversation_created_idx
  on public.messages (conversation_id, created_at);

create table public.message_read_receipts (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  status public.message_delivery_status not null,
  created_at timestamptz not null default now(),
  constraint message_read_receipts_status_check
    check (status in ('delivered', 'read'))
);

create unique index message_read_receipts_unique_idx
  on public.message_read_receipts (message_id, profile_id, status);

-- ---------------------------------------------------------------------------
-- Stato piattaforma per bridge stateless (ADR D-051)
-- ---------------------------------------------------------------------------

create table public.outbox (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages (id) on delete cascade,
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  protocol public.contact_protocol not null,
  payload jsonb not null default '{}'::jsonb,
  status public.queue_status not null default 'queued',
  locked_by text,
  locked_at timestamptz,
  attempts integer not null default 0,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index outbox_status_created_idx on public.outbox (status, created_at);

create table public.sync_cursors (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  conversation_id uuid references public.conversations (id) on delete cascade,
  protocol public.contact_protocol not null,
  cursor_key text not null,
  cursor_value text not null,
  updated_at timestamptz not null default now(),
  unique (profile_id, conversation_id, protocol, cursor_key)
);

create table public.bridge_jobs (
  id uuid primary key default gen_random_uuid(),
  job_type text not null,
  protocol public.contact_protocol not null,
  payload jsonb not null default '{}'::jsonb,
  status public.queue_status not null default 'queued',
  locked_by text,
  locked_at timestamptz,
  idempotency_key text unique,
  attempts integer not null default 0,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index bridge_jobs_status_created_idx on public.bridge_jobs (status, created_at);

-- ---------------------------------------------------------------------------
-- Trigger: profilo alla registrazione
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
begin
  v_username := lower(coalesce(new.raw_user_meta_data ->> 'username', split_part(new.email, '@', 1)));
  v_username := regexp_replace(v_username, '[^a-z0-9_]', '_', 'g');
  if length(v_username) < 3 then
    v_username := 'user_' || substr(replace(new.id::text, '-', ''), 1, 8);
  end if;

  v_display_name := coalesce(
    new.raw_user_meta_data ->> 'display_name',
    initcap(replace(v_username, '_', ' '))
  );

  insert into public.profiles (id, username, display_name)
  values (new.id, v_username, v_display_name)
  on conflict (id) do nothing;

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Helper: utente partecipa alla conversazione?
-- ---------------------------------------------------------------------------

create or replace function public.is_conversation_participant(p_conversation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.conversation_participants cp
    where cp.conversation_id = p_conversation_id
      and cp.profile_id = auth.uid()
  );
$$;

-- ---------------------------------------------------------------------------
-- Trigger: messaggio inserito → preview, unread, outbox (federati)
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

  v_preview := left(trim(new.body), 120);
  if v_preview = '' and new.marker_type is not null then
    v_preview := '[stato messaggio]';
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

  if v_protocol in ('xmpp', 'matrix') then
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
        'sender_id', new.sender_id,
        'client_message_id', new.client_message_id
      )
    );
  end if;

  return new;
end;
$$;

create trigger messages_after_insert
  after insert on public.messages
  for each row execute function public.on_message_inserted();

-- ---------------------------------------------------------------------------
-- RPC: ricerca profili interni (per aggiunta contatti)
-- ---------------------------------------------------------------------------

create or replace function public.search_profiles(p_query text, p_limit integer default 20)
returns table (
  id uuid,
  username text,
  display_name text,
  avatar_url text
)
language sql
stable
security definer
set search_path = public
as $$
  select p.id, p.username, p.display_name, p.avatar_url
  from public.profiles p
  where auth.uid() is not null
    and p.id <> auth.uid()
    and (
      p.username ilike '%' || p_query || '%'
      or p.display_name ilike '%' || p_query || '%'
    )
  order by p.display_name
  limit greatest(1, least(p_limit, 50));
$$;

-- ---------------------------------------------------------------------------
-- RPC: conversazione diretta interna (deduplicata)
-- ---------------------------------------------------------------------------

create or replace function public.get_or_create_direct_conversation(p_other_profile_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_conv_id uuid;
begin
  if v_me is null then
    raise exception 'not authenticated';
  end if;

  if p_other_profile_id = v_me then
    raise exception 'cannot chat with yourself';
  end if;

  select c.id into v_conv_id
  from public.conversations c
  inner join public.conversation_participants cp1
    on cp1.conversation_id = c.id and cp1.profile_id = v_me
  inner join public.conversation_participants cp2
    on cp2.conversation_id = c.id and cp2.profile_id = p_other_profile_id
  where c.is_group = false
    and c.protocol = 'internal'
  limit 1;

  if v_conv_id is not null then
    return v_conv_id;
  end if;

  insert into public.conversations (protocol, is_group)
  values ('internal', false)
  returning id into v_conv_id;

  insert into public.conversation_participants (conversation_id, profile_id)
  values
    (v_conv_id, v_me),
    (v_conv_id, p_other_profile_id);

  return v_conv_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: conversazione da contatto (interno / federato)
-- ---------------------------------------------------------------------------

create or replace function public.get_or_create_conversation_from_contact(p_contact_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_contact public.contacts%rowtype;
  v_conv_id uuid;
begin
  if v_me is null then
    raise exception 'not authenticated';
  end if;

  select * into v_contact
  from public.contacts
  where id = p_contact_id and owner_id = v_me;

  if not found then
    raise exception 'contact not found';
  end if;

  if v_contact.protocol = 'internal' then
    return public.get_or_create_direct_conversation(v_contact.linked_profile_id);
  end if;

  select cp.conversation_id into v_conv_id
  from public.conversation_participants cp
  inner join public.conversations c on c.id = cp.conversation_id
  where cp.profile_id = v_me
    and cp.contact_id = p_contact_id
    and c.is_group = false
  limit 1;

  if v_conv_id is not null then
    return v_conv_id;
  end if;

  insert into public.conversations (protocol, is_group, title)
  values (v_contact.protocol, false, v_contact.display_name)
  returning id into v_conv_id;

  insert into public.conversation_participants (conversation_id, profile_id, contact_id)
  values (v_conv_id, v_me, p_contact_id);

  return v_conv_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: segna conversazione come letta
-- ---------------------------------------------------------------------------

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
    and m.body <> ''
    and m.marker_type is null
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

-- ---------------------------------------------------------------------------
-- RPC: invio messaggio (validazione lato server)
-- ---------------------------------------------------------------------------

create or replace function public.send_message(
  p_conversation_id uuid,
  p_body text,
  p_client_message_id text default null
)
returns public.messages
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_row public.messages;
begin
  if v_me is null then
    raise exception 'not authenticated';
  end if;

  if not public.is_conversation_participant(p_conversation_id) then
    raise exception 'not a participant';
  end if;

  if length(trim(p_body)) = 0 then
    raise exception 'empty message';
  end if;

  insert into public.messages (
    conversation_id,
    sender_id,
    body,
    client_message_id,
    delivery_status
  )
  values (
    p_conversation_id,
    v_me,
    trim(p_body),
    p_client_message_id,
    'sent'
  )
  returning * into v_row;

  return v_row;
end;
$$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.contacts enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_participants enable row level security;
alter table public.messages enable row level security;
alter table public.message_read_receipts enable row level security;
alter table public.outbox enable row level security;
alter table public.sync_cursors enable row level security;
alter table public.bridge_jobs enable row level security;

-- profiles
create policy profiles_select_authenticated
  on public.profiles for select to authenticated
  using (true);

create policy profiles_update_own
  on public.profiles for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- contacts
create policy contacts_select_own
  on public.contacts for select to authenticated
  using (owner_id = auth.uid());

create policy contacts_insert_own
  on public.contacts for insert to authenticated
  with check (owner_id = auth.uid());

create policy contacts_update_own
  on public.contacts for update to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy contacts_delete_own
  on public.contacts for delete to authenticated
  using (owner_id = auth.uid());

-- conversations
create policy conversations_select_participant
  on public.conversations for select to authenticated
  using (public.is_conversation_participant(id));

-- conversation_participants
create policy participants_select_own_or_shared
  on public.conversation_participants for select to authenticated
  using (
    profile_id = auth.uid()
    or public.is_conversation_participant(conversation_id)
  );

create policy participants_update_own
  on public.conversation_participants for update to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

-- messages
create policy messages_select_participant
  on public.messages for select to authenticated
  using (public.is_conversation_participant(conversation_id));

create policy messages_insert_participant
  on public.messages for insert to authenticated
  with check (
    sender_id = auth.uid()
    and public.is_conversation_participant(conversation_id)
  );

-- read receipts
create policy receipts_select_participant
  on public.message_read_receipts for select to authenticated
  using (
    exists (
      select 1 from public.messages m
      where m.id = message_id
        and public.is_conversation_participant(m.conversation_id)
    )
  );

create policy receipts_insert_own
  on public.message_read_receipts for insert to authenticated
  with check (profile_id = auth.uid());

-- bridge tables: nessun accesso client (solo service_role)
create policy outbox_deny_authenticated
  on public.outbox for all to authenticated
  using (false) with check (false);

create policy sync_cursors_deny_authenticated
  on public.sync_cursors for all to authenticated
  using (false) with check (false);

create policy bridge_jobs_deny_authenticated
  on public.bridge_jobs for all to authenticated
  using (false) with check (false);

-- Realtime publication
alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.conversations;
alter publication supabase_realtime add table public.conversation_participants;
