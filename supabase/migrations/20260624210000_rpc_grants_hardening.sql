-- Revoca EXECUTE su funzioni interne/trigger da anon; RPC client solo per authenticated.

REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.on_message_inserted() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.is_conversation_participant(uuid) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.search_profiles(text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_or_create_direct_conversation(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_or_create_conversation_from_contact(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_conversation_read(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.send_message(uuid, text, text) TO authenticated;

REVOKE ALL ON FUNCTION public.search_profiles(text, integer) FROM anon;
REVOKE ALL ON FUNCTION public.get_or_create_direct_conversation(uuid) FROM anon;
REVOKE ALL ON FUNCTION public.get_or_create_conversation_from_contact(uuid) FROM anon;
REVOKE ALL ON FUNCTION public.mark_conversation_read(uuid) FROM anon;
REVOKE ALL ON FUNCTION public.send_message(uuid, text, text) FROM anon;
