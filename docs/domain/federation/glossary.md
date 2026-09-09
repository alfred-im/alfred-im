# Glossario — contesto federation

**Bounded context:** `federation`  
**Ultima revisione:** 2026-09-09

---

## Linguaggio ubiquo

| Termine | Definizione |
|---------|-------------|
| **Federation** | Messaggistica tra istanze Alfred (`user@server` verso altra istanza). |
| **Istanza** | Deploy Alfred (Supabase + client Fly) con `im_server_id` proprio. |
| **Indirizzo federato** | `username@im_server_id` — stesso formato in compose, rubrica e messaggistica. |
| **Gateway federativo** | Terminazione HTTP/3 verso peer; discovery e ingest eventi inbound. |
| **Worker federativo** | Claim `outbox`, traduzione wire ↔ piattaforma, materialize inbound. |
| **logical_message_id** | Id globale mintato dal server mittente; replicato sulla copia destinatario. |
| **Outbox** | Coda eventi (`deliver`, `read_receipt`, `reaction_fact`, …) processata dal worker. |

---

## Confini

| Contesto | Relazione |
|----------|-----------|
| **messaging** | Stessa pipeline mailbox; federato differisce solo nel driver di recapito (worker federativo vs locale sincrono). |
| **reception** | Allow list locale + esterna (`allowed_profile_id` / `allowed_external_address`) — [gotham-protocol.md § 5.4](../../architecture/gotham-protocol.md). |
| **contacts** | Rubrica può salvare `external_address`; non implica recapito finché la federazione non è live. |

---

## Riferimenti

- [gotham-protocol.md](../../architecture/gotham-protocol.md) — contratto wire (nome protocollo solo qui)
- [gotham.proto](../../specs/contracts/gotham.proto)
