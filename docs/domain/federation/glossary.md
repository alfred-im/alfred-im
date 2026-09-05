# Glossario — contesto federation

**Bounded context:** `federation`  
**Ultima revisione:** 2026-09-05  
**Stato runtime:** bridge stub (health only); protocollo Gotham documentato — vedi [gotham-protocol.md](../../architecture/gotham-protocol.md).

---

## Linguaggio ubiquo

| Termine | Definizione |
|---------|-------------|
| **Gotham** | Protocollo federazione nativo Alfred — HTTP/3, Protobuf, discovery `/.well-known/gotham`, invio `POST /gotham/v1/events`. |
| **Gotham envelope** | Messaggio wire `GothamEnvelope` — vedi [gotham.proto](../../specs/contracts/gotham.proto). |
| **Federation** | Messaggistica tra istanze Alfred (Gotham) o, in futuro, verso XMPP/Matrix tramite bridge dedicati. |
| **Contact protocol** | Routing backend: `internal`, `gotham` (target), `xmpp`, `matrix` — invisibile in inbox UI standard. |
| **Bridge (stateless)** | Processo senza stato business locale — vedi [bridge-stateless.md](../../decisions/bridge-stateless.md). |
| **Platform truth** | Piattaforma tiene outbox, worker, mapping identità; bridge traduce solo. |
| **Federated outbox** | Stesso bus outbox; su federato `status = queued` fino a claim bridge (non worker sync internal). |
| **Logical message id** | Id globale messaggio — mintato dal server mittente; replicato identico sul destinatario; unico id federativo per MESSAGE/LOCATION. |
| **Read receipt id** | Id federativo evento lettura — mintato dal server lettore; replicato sul mittente. |
| **Reaction fact id** | Id federativo evento reaction — mintato dal server reagente. |
| **Object logical message id** | Su envelope Gotham READ/REACTION: il messaggio su cui agisce l'evento. |
| **External id** (DB) | Id da protocolli legacy (XMPP/Matrix) su `messages.external_id` — non usato da Gotham nativo. |
| **Sync cursor** | Watermark sync per coppia profilo/protocollo (bridge legacy). |
| **Inbound federato** | `POST /gotham/v1/events` → bridge → gate reception → materialize destinatario. |
| **Outbound federato** | outbox → bridge → Gotham verso peer. |
| **Federated ack (MESSAGE)** | HTTP 2xx sul POST — non body strutturato. |
| **Gateway** | Servizio Fly HTTP/3 che termina QUIC ed espone endpoint Gotham per l'istanza. |

---

## Confini

| Contesto | Relazione |
|----------|-----------|
| **delivery** | Internal: worker sync; federato: stesso outbox, consumer bridge. |
| **messaging** | Client invia sempre via piattaforma; non parla Gotham direttamente. |
| **reception** | Gate allow list su inbound bridge. |
| **contacts** | Rubrica salva indirizzi `user@server` per routing federato. |

---

## Invarianti

1. Bridge **non** conservano stato autorevole — solo cache volatile rigenerabile.
2. Stesso modello caselle: copie archivio indipendenti, `logical_message_id` per correlazione messaggi.
3. READ e REACTION sono eventi separati con id propri; ack MESSAGE = solo HTTP status.
4. Retry bridge: stessi id federativi; dedup lato ricevente su quegli id.
5. Server mittente minta `logical_message_id`; destinatario **non** rigenera.
6. Client web → **solo** piattaforma; mai connessione diretta Gotham dal client.
