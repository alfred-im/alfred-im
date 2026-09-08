# Glossario — contesto federation

**Bounded context:** `federation`  
**Ultima revisione:** 2026-09-08

---

## Linguaggio ubiquo

| Termine | Definizione |
|---------|-------------|
| **Federation** | Messaggistica tra istanze Alfred tramite protocollo nativo **Gotham**. |
| **Istanza** | Deploy Alfred (Supabase + client Fly) con `im_server_id` proprio. |
| **Indirizzo federato** | `username@im_server_id` — stesso formato in compose, rubrica e messaggistica. |
| **Gateway Gotham** | Terminazione HTTP/3 verso peer; espone `/.well-known/gotham` e `/gotham/v1/events`. |
| **Worker Gotham** | Claim `outbox`, traduzione Protobuf ↔ piattaforma, materialize inbound. |
| **logical_message_id** | Id globale mintato dal server mittente; replicato sulla copia destinatario. |
| **Outbox** | Coda eventi (`deliver`, `read_receipt`, `reaction_fact`, …) processata dal worker. |

---

## Confini

| Contesto | Relazione |
|----------|-----------|
| **messaging** | Stessa pipeline mailbox; federato differisce solo nel driver di recapito (worker Gotham vs internal sincrono). |
| **reception** | Allow list del destinatario vale anche per inbound federato. |
| **contacts** | Rubrica può salvare `external_address`; non implica recapito finché Gotham non è live. |

---

## Riferimenti

- [gotham-protocol.md](../../architecture/gotham-protocol.md)
- [gotham.proto](../../specs/contracts/gotham.proto)
