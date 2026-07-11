-- RECEPTION-ALLOWLIST-REQ-028, GROUP-CORE-REQ-024, GROUP-DELIVERY-REQ-027
-- Helper interni: authenticated non deve poterli invocare via PostgREST.

DO $$
BEGIN
  IF has_function_privilege(
    'authenticated',
    'public.is_sender_allowed_for_reception(uuid, uuid)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'is_sender_allowed_for_reception must not be executable by authenticated';
  END IF;

  IF has_function_privilege(
    'authenticated',
    'public.is_bidirectional_allowed(uuid, uuid, uuid)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'is_bidirectional_allowed must not be executable by authenticated';
  END IF;

  IF has_function_privilege(
    'authenticated',
    'public.profile_kind_of(uuid)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'profile_kind_of must not be executable by authenticated';
  END IF;

  IF has_function_privilege(
    'authenticated',
    'alfred_delivery.erogate_group_message(uuid, uuid, uuid, public.contact_protocol, text, public.message_content_type, text, integer, text, bigint, double precision, double precision)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'alfred_delivery.erogate_group_message must not be executable by authenticated';
  END IF;

  RAISE NOTICE 'rpc_helper_security_smoke_ok';
END $$;
