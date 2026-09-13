# Invarianti — groups

**Bounded context:** `groups`  
**Implementazione:** `client/lib/machines/groups/`, RPC gruppo  
**Confine prodotto:** [SYS-GROUP](../../specs/promises/system/SYS-GROUP.md)  
**Ultima revisione:** 2026-09-13  
**Amend:** §7.18 TEMP — gruppi come account address-based

---

1. Account `profile_kind = group` ha identità propria (nome, avatar) — identità = `@username` come qualsiasi account.
2. Partecipazione **solo** allow list bidirezionale — nessuna membership table ([SYS-GROUP](../../specs/promises/system/SYS-GROUP.md)).
3. Shell gruppo: nessuna inbox 1:1; broadcast verso allow list del gruppo via `broadcast_message_to_allowlist`.
4. Chat umano → gruppo (account `user` verso gruppo): `peer_address` = indirizzo gruppo (es. `team` o `team@arkham-im.fly.dev` secondo regole bare vs FQDN); inbox / allow list / compose / link — stesse regole address-based di qualsiasi account.
5. Chat 1:1 con peer gruppo: storico per `peer_address`; etichetta autore obbligatoria ([PROM-GROUP-AUTHOR-DISPLAY](../../specs/promises/product/PROM-GROUP-AUTHOR-DISPLAY.md)).
6. Erogazione automatica verso allow list del gruppo lato worker — client non scrive archivio cross-archive.
7. Archivio interno gruppo: bounded context separato (`SYS-GROUP`: broadcast, righe senza `peer_address` controparte umana) — **non** esenta il gruppo dall'identità address-based verso l'esterno.
