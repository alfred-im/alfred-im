-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- Instance branding storage (owner upload) + push icon_url in outbox payload.

-- ---------------------------------------------------------------------------
-- Storage: bucket instance-branding (logo / favicon shell PWA)
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'instance-branding',
  'instance-branding',
  true,
  2097152,
  array['image/jpeg', 'image/png', 'image/webp', 'image/x-icon', 'image/vnd.microsoft.icon']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy instance_branding_select_public
  on storage.objects for select
  using (bucket_id = 'instance-branding');

create policy instance_branding_insert_owner
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'instance-branding'
    and public.is_instance_owner()
  );

create policy instance_branding_update_owner
  on storage.objects for update to authenticated
  using (
    bucket_id = 'instance-branding'
    and public.is_instance_owner()
  )
  with check (
    bucket_id = 'instance-branding'
    and public.is_instance_owner()
  );

create policy instance_branding_delete_owner
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'instance-branding'
    and public.is_instance_owner()
  );

-- ---------------------------------------------------------------------------
-- Push: icon_url from instance.branding.logo_url
-- ---------------------------------------------------------------------------

create or replace function alfred_delivery.queue_push_after_delivery(
  p_recipient_user_id uuid,
  p_peer_profile_id uuid,
  p_logical_message_id uuid,
  p_content_type public.message_content_type,
  p_body text,
  p_original_author_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public, alfred_delivery
as $$
declare
  v_recipient_message_id uuid;
  v_peer_name text;
  v_recipient_name text;
  v_recipient_username text;
  v_preview text;
  v_author_name text;
  v_icon_url text;
  v_payload jsonb;
  v_outbox_id uuid;
begin
  if p_recipient_user_id is null or p_peer_profile_id is null or p_logical_message_id is null then
    return;
  end if;

  if not exists (
    select 1 from public.push_subscriptions ps where ps.user_id = p_recipient_user_id
  ) then
    return;
  end if;

  select m.id
  into v_recipient_message_id
  from public.messages m
  where m.owner_id = p_recipient_user_id
    and m.logical_message_id = p_logical_message_id
  limit 1;

  if v_recipient_message_id is null then
    return;
  end if;

  select p.display_name into v_peer_name
  from public.profiles p
  where p.id = p_peer_profile_id;

  select p.display_name, p.username
  into v_recipient_name, v_recipient_username
  from public.profiles p
  where p.id = p_recipient_user_id;

  v_preview := public.message_preview_text(p_content_type, p_body);

  if p_original_author_id is not null
     and p_original_author_id <> p_peer_profile_id then
    select p.display_name into v_author_name
    from public.profiles p
    where p.id = p_original_author_id;

    if v_author_name is not null and length(trim(v_author_name)) > 0 then
      v_preview := v_author_name || ': ' || v_preview;
    end if;
  end if;

  select nullif(trim(c.value ->> 'logo_url'), '')
  into v_icon_url
  from public.instance_config c
  where c.key = 'instance.branding';

  v_payload := jsonb_build_object(
    'event_kind', 'push_notify',
    'recipient_user_id', p_recipient_user_id,
    'recipient_display_name', coalesce(v_recipient_name, 'Alfred'),
    'recipient_username', v_recipient_username,
    'peer_profile_id', p_peer_profile_id,
    'peer_display_name', coalesce(v_peer_name, 'Alfred'),
    'preview_text', v_preview,
    'logical_message_id', p_logical_message_id,
    'content_type', p_content_type::text,
    'icon_url', v_icon_url
  );

  insert into public.outbox (message_id, protocol, payload, status)
  values (v_recipient_message_id, 'internal', v_payload, 'queued')
  returning id into v_outbox_id;

  perform alfred_delivery.process_push_notify(v_outbox_id);
end;
$$;
