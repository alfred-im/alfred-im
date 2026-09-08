# Comandi ed eventi — contesto federation

**Ultima revisione:** 2026-09-08  
**UML:** [docs/model/uml/federation/](../../model/uml/federation/)

Target — worker Gotham non ancora implementato.

---

## Comandi

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `QueueFederatedSend` | Policy (invio verso `peer_external_address`) | Accoda messaggio in outbox per worker Gotham. |
| `DeliverToFederatedPeer` | Worker Gotham | POST verso istanza peer (`/gotham/v1/events`). |
| `ReceiveFromFederatedPeer` | Gateway Gotham | Riceve envelope inbound da peer remoto. |
| `ApplyFederatedAck` | Worker Gotham | Propaga conferme recapito/lettura/reazione. |

UML platform outbound (target): [seq-federation-stub.puml](../../model/uml/federation/seq-federation-stub.puml).

Inbound federato: `GothamWorker` → `ReceptionGate` : `EvaluateInboundDelivery` — vedi [seq-federation-inbound.puml](../../model/uml/federation/seq-federation-inbound.puml).

---

## Eventi

| Evento | Descrizione |
|--------|-------------|
| `FederatedSendQueued` | In attesa di worker Gotham. |
| `FederatedMessageDelivered` | Peer ha accettato (HTTP 2xx). |
| `InboundFederatedMessageReceived` | Messaggio federato materializzato in archivio Alfred. |
| `FederatedAckApplied` | Spunte aggiornate da evento READ/deliver federato. |

---

## Policy

| Policy | Descrizione |
|--------|-------------|
| **Worker stateless** | Stato autorevole solo su piattaforma (Postgres). |
| **Stesso modello caselle** | Copie archivio indipendenti con correlazione `logical_message_id`. |
| **Gate reception su inbound** | Allow list anche per messaggi federati in ingresso. |
