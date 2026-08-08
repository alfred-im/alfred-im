# Contesto: federation

**Stato modellazione:** `documented` (runtime stub)

## Mapping dominio → implementazione (target)

| Dominio | Implementazione |
|---------|-----------------|
| `QueueFederatedSend` | outbox `protocol = xmpp\|matrix` |
| `FederatedSendQueued` | outbox `status = queued` |
| `DeliverToFederatedPeer` | bridge claim outbox + translate protocollo |
| `FederatedMessageDelivered` | UPDATE `delivered_at` / ack esterno sulla copia mittente |
| `ReceiveFromFederatedPeer` | bridge ingest + `EvaluateInboundDelivery` + INSERT copia destinatario |
| `InboundFederatedMessageReceived` | copia destinatario materializzata |
| `ApplyFederatedAck` | UPDATE spunte via `external_id` / λ |
| `FederatedAckApplied` | `delivered_at` / `read_at` aggiornati su copia mittente |

Attuale: `bridge-xmpp` / `bridge-matrix` — solo `GET /health`
