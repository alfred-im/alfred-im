# Invarianti — groups

**Bounded context:** `groups`  
**Implementazione:** `client/lib/machines/groups/`, RPC gruppo  
**Confine prodotto:** [SYS-GROUP](../../specs/promises/system/SYS-GROUP.md)

---

1. Account `profile_kind = group` ha identità propria (nome, avatar) — non è un «gruppo XMPP» ([WISHLIST](../../WISHLIST.md)).
2. Partecipazione **solo** allow list bidirezionale — nessuna membership table ([SYS-GROUP](../../specs/promises/system/SYS-GROUP.md)).
3. Shell gruppo: nessuna inbox 1:1; broadcast verso allow list del gruppo via `broadcast_message_to_allowlist`.
4. Chat 1:1 con peer gruppo (account `user`): storico per `peer_profile_id`; etichetta autore obbligatoria ([PROM-GROUP-AUTHOR-DISPLAY](../../specs/promises/product/PROM-GROUP-AUTHOR-DISPLAY.md)).
5. Erogazione automatica verso allow list del gruppo lato worker — client non scrive archivio cross-archive.
