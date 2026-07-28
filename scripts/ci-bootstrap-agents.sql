-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- Bootstrap utenti CI con UUID fissi (allineati agli smoke SQL).
-- Idempotente: sicuro su supabase start ripetuto.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
DECLARE
  v_instance uuid := '00000000-0000-0000-0000-000000000000';
  v_agent1 uuid := 'efd885fe-b36e-48fc-a796-0e3f153e40d6';
  v_agent2 uuid := '0a81f785-173c-4f1c-b5df-3937086a2482';
BEGIN
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = v_agent1) THEN
    INSERT INTO auth.users (
      instance_id,
      id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at,
      confirmation_token,
      recovery_token,
      email_change_token_new,
      email_change
    ) VALUES (
      v_instance,
      v_agent1,
      'authenticated',
      'authenticated',
      'ci-agent1@e2e.local.test',
      crypt('CiAgentPass1!', gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"username":"ciagent1","display_name":"CI Agent 1"}'::jsonb,
      now(),
      now(),
      '',
      '',
      '',
      ''
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = v_agent2) THEN
    INSERT INTO auth.users (
      instance_id,
      id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at,
      confirmation_token,
      recovery_token,
      email_change_token_new,
      email_change
    ) VALUES (
      v_instance,
      v_agent2,
      'authenticated',
      'authenticated',
      'ci-agent2@e2e.local.test',
      crypt('CiAgentPass2!', gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"username":"ciagent2","display_name":"CI Agent 2"}'::jsonb,
      now(),
      now(),
      '',
      '',
      '',
      ''
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = '5b9fadb5-884a-41f2-89c9-4ced56be07a2') THEN
    INSERT INTO auth.users (
      instance_id,
      id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at,
      confirmation_token,
      recovery_token,
      email_change_token_new,
      email_change
    ) VALUES (
      v_instance,
      '5b9fadb5-884a-41f2-89c9-4ced56be07a2',
      'authenticated',
      'authenticated',
      'ci-observer@e2e.local.test',
      crypt('CiObserverPass1!', gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"username":"ciobserver","display_name":"CI Observer"}'::jsonb,
      now(),
      now(),
      '',
      '',
      '',
      ''
    );
  END IF;

  INSERT INTO public.reception_allowlist (owner_id, allowed_profile_id)
  VALUES (v_agent1, v_agent2), (v_agent2, v_agent1)
  ON CONFLICT DO NOTHING;
END $$;
