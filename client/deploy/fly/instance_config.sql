-- Istanza demo Fly Arkham (tvwpoxxcqwphryvuyqzu).
-- Seed opzionale: i valori runtime vivono in instance_config (DB), non nel build.
-- Eseguire su Supabase live dopo migration instance_config, o usare il pannello owner.
-- Idempotente: upsert su chiave.

insert into public.instance_config (key, value) values
  ('instance.display_name', '"Arkham"'::jsonb),
  ('instance.im_server_id', '"arkham-im.fly.dev"'::jsonb)
on conflict (key) do update
  set value = excluded.value,
      updated_at = now();
