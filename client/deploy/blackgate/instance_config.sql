-- Istanza demo Fly Blackgate — eseguire sul progetto Supabase Blackgate dopo le migration.
-- Seed opzionale: i valori runtime vivono in instance_config (DB), non nel build.
-- Idempotente: upsert su chiave.

insert into public.instance_config (key, value) values
  ('instance.display_name', '"Blackgate.im"'::jsonb),
  ('instance.im_server_id', '"blackgate-im.fly.dev"'::jsonb)
on conflict (key) do update
  set value = excluded.value,
      updated_at = now();
