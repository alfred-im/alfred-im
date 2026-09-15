# Glossario — contesto federation

**Bounded context:** `federation`  
**Ultima revisione:** 2026-09-15  
**Amend:** peer_address — [PROM-CHAT-PEER-KEY](../../specs/promises/product/PROM-CHAT-PEER-KEY.md) · [schema.md](../../specs/contracts/schema.md)

---

## Linguaggio ubiquo

| Termine | Definizione |
|---------|-------------|
| **Federation** | Messaggistica tra istanze Alfred (`user@server` verso altra istanza). |
| **Istanza** | Deploy Alfred (Supabase + client) con `im_server_id` proprio. |
| **`im_server_id`** | Dominio identità IM (`@server` negli indirizzi) **e** host del wire Gotham (discovery + `/gotham/v1/events`). |
| **`publicBaseUrl`** | Solo hosting client web Flutter — **fuori** dal wire federativo; può essere white-label su dominio terzo. |
| **Indirizzo federato** | `username@im_server_id` — stesso formato in compose, rubrica, allow list e messaggistica. |
| **peer_address** | Chiave conversazione — stringa lowercase; federato e locale condividono lo stesso modello account. |
| **author_address** | Identità mittente su copia archivio; inbound federato = indirizzo completo da envelope (`from_address`). |
| **Gateway federativo** | Terminazione HTTP/3 verso peer; discovery e ingest eventi inbound. |
| **Erogazione internal** | Recapito verso destinatario sulla stessa istanza (DB locale). Implementazione: worker internal (`alfred_delivery`). |
| **Erogazione external (Gotham)** | Recapito verso `@server` remoto via HTTP/3 + Protobuf. Implementazione: worker Gotham. |
| **Worker** (solo in doc federazione) | **Solo erogazione** — internal o Gotham. **Non** outbox né spunte (unificate). |
| **Modulo spunte unificato** | Applica `delivered_at` / `read_at` sulla copia mittente dopo erogazione ok — un’implementazione per internal e Gotham. |
| **logical_message_id** | Id globale mintato dal server mittente; replicato sulla copia destinatario. |
| **Outbox** | Coda eventi (`deliver`, `read_receipt`, `reaction_fact`, …) processata dal worker. |
| **get_profiles (federato)** | Piattaforma interroga Gotham sul peer (`/gotham/v1/profiles` o GET singolo); finché assente → fallback indirizzo grezzo. |
| **PublicProfile** | Messaggio protobuf wire — profilo pubblico remoto; allinea campi RPC `get_profiles`. |

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
- [address-based-messaging.md](../../decisions/address-based-messaging.md) — modello address-based
