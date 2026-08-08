# Invarianti — contacts

**Bounded context:** `contacts`  
**Implementazione:** `client/lib/machines/contacts/`, `ContactService`  
**Confine prodotto:** [SYS-CONTACTS](../../specs/promises/system/SYS-CONTACTS.md), [PROM-PERSONAL-CONTACTS](../../specs/promises/product/PROM-PERSONAL-CONTACTS.md)

---

1. Rubrica personale isolata da inbox, allow list e messaggistica — aggiungere un contatto **non** abilita recapito.
2. Ricerca persone (`search_profiles`) è on-demand UI — non evento `ContactsMachine` ([PROM-LIST-FILTER](../../specs/promises/product/PROM-LIST-FILTER.md)).
3. `StartChatFromContact` delega a navigation (`OpenPeerOnFocusedAccount`) — contacts non possiede scope conversazione.
4. Contatti esterni (`user@server`) salvabili in rubrica; invio messaggio resta `unsupported` senza federazione ([address-based-messaging](../../decisions/address-based-messaging.md)).
