-- Instance-scoped configuration (key → JSON). Software reads via RPC only.

create table public.instance_config (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);

revoke all on table public.instance_config from public, anon, authenticated;

comment on table public.instance_config is
  'Per-instance service settings (display name, IM server id, branding, legal). Not Alfred software config.';

-- Bootstrap payload for client startup (instance.* keys only).
create or replace function public.get_instance_bootstrap()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_object_agg(key, value), '{}'::jsonb)
  from public.instance_config
  where key like 'instance.%';
$$;

revoke all on function public.get_instance_bootstrap() from public;
grant execute on function public.get_instance_bootstrap() to anon, authenticated;

-- Publishable VAPID key for Web Push (private key stays in alfred_delivery.push_settings).
create or replace function public.get_push_vapid_public_key()
returns text
language sql
stable
security definer
set search_path = public, alfred_delivery
as $$
  select vapid_public_key
  from alfred_delivery.push_settings
  where singleton is true
  limit 1;
$$;

revoke all on function public.get_push_vapid_public_key() from public;
grant execute on function public.get_push_vapid_public_key() to anon, authenticated;

-- Local / fresh instance defaults (operators override per deployment).
insert into public.instance_config (key, value) values
  ('instance.display_name', '"Local"'::jsonb),
  ('instance.im_server_id', '"localhost"'::jsonb)
on conflict (key) do nothing;
