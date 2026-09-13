# Invarianti — contacts

**Bounded context:** `contacts`  
**Implementazione:** `client/lib/machines/contacts/`, `ContactService`  
**Confine prodotto:** [SYS-CONTACTS](../../specs/promises/system/SYS-CONTACTS.md), [PROM-PERSONAL-CONTACTS](../../specs/promises/product/PROM-PERSONAL-CONTACTS.md)  
**Ultima revisione:** 2026-09-13

---

1. Rubrica personale isolata da inbox, allow list e messaggistica — aggiungere un contatto **non** abilita recapito.
2. Ricerca persone (`search_profiles`) è on-demand UI — non evento `ContactsMachine` ([PROM-LIST-FILTER](../../specs/promises/product/PROM-LIST-FILTER.md)).
3. `StartChatFromContact` delega a navigation (`OpenPeerOnFocusedAccount`) con `peer_address` — contacts non possiede scope conversazione.
4. `contacts` salva **solo** `address` lowercase — nessun snapshot nome/avatar, nessun split `linked_profile_id` / `external_address`.
5. Presentazione contatti: batch `get_profiles(addresses[])` — fallback indirizzo grezzo.
