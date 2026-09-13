# Glossario — contesto federation

**Bounded context:** `federation`  
**Ultima revisione:** 2026-09-13  
**Amend:** peer_address — distillazione TEMP §7

---

## Linguaggio ubiquo

| Termine | Definizione |
|---------|-------------|
| **Federation** | Messaggistica tra istanze Alfred (`user@server` verso altra istanza). |
| **Istanza** | Deploy Alfred (Supabase + client Fly) con `im_server_id` proprio. |
| **Indirizzo federato** | `username@im_server_id` — stesso formato in compose, rubrica, allow list e messaggistica. |
| **peer_address** | Chiave conversazione — stringa lowercase; federato e locale condividono lo stesso modello account. |
| **author_address** | Identità mittente su copia archivio; inbound federato = indirizzo completo da envelope (`from_address`). |
| **Gateway federativo** | Terminazione HTTP/3 verso peer; discovery e ingest eventi inbound. |
| **Worker federativo** | Claim `outbox`, traduzione wire ↔ piattaforma, materialize inbound. |
| **logical_message_id** | Id globale mintato dal server mittente; replicato sulla copia destinatario. |
| **Outbox** | Coda eventi (`deliver`, `read_receipt`, `reaction_fact`, …) processata dal worker. |
| **get_profiles (federato)** | Wire profilo dedicato (passo 5); prima del wire: ramo locale + fallback indirizzo grezzo. |

---

## Confini

| Contesto | Relazione |
|----------|-----------|
| **messaging** | Stessa pipeline mailbox; federato differisce solo nel driver di recapito (worker federativo vs locale sincrono). Chiave = `peer_address`. |
| **reception** | Allow list su `allowed_address` — gate anche per messaggi federati in ingresso. |
| **contacts** | Rubrica salva `address` (`user@server` incluso); non implica recapito senza allow list. |
| **profile** | `get_profiles` serve profilo pubblico senza gate allow list del richiedente; istanza origine serve profilo. |
| **navigation** | Push e link keyed su `peerAddress`; shareable-link accetta `user@other-server`. |

---

## Riferimenti

- [gotham-protocol.md](../../architecture/gotham-protocol.md) — contratto wire (nome protocollo solo qui)
- [gotham.proto](../../specs/contracts/gotham.proto)
- [TEMP-chat-peer-key-address-drift.md](../../tmp/TEMP-chat-peer-key-address-drift.md) §7 — modello address-based
