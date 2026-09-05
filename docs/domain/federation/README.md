# Contesto: federation

**Stato modellazione:** `documented` (runtime stub)  
**Protocollo wire target:** [Gotham](../../architecture/gotham-protocol.md) · [gotham.proto](../../specs/contracts/gotham.proto)

## Protocollo

| Protocollo | Ruolo |
|------------|-------|
| **Gotham** | Federazione nativa Alfred (HTTP/3 + Protobuf) — **target** |
| XMPP / Matrix | Legacy / bridge esterni opzionali — stub `GET /health` |

## Mapping dominio → implementazione (Gotham)

| Dominio | Implementazione |
|---------|-----------------|
| `QueueFederatedSend` | outbox `protocol = gotham` (o estensione `contact_protocol`) |
| `FederatedSendQueued` | outbox `status = queued` (no worker sync) |
| `DeliverToFederatedPeer` | bridge claim outbox → `POST /gotham/v1/events` |
| `FederatedMessageDelivered` | HTTP 2xx → `delivered_at` copia mittente |
| `ReceiveFromFederatedPeer` | gateway inbound → bridge → gate reception → materialize |
| `InboundFederatedMessageReceived` | `materialize_inbound_sender_message` (id remoto invariato) |
| `ApplyFederatedAck` | Eventi READ separati (`read_receipt_id`); ack MESSAGE = HTTP status |
| `FederatedAckApplied` | `delivered_at` / `read_at` + `read_receipt_id` su copia mittente |

Attuale runtime: `bridge-xmpp` / `bridge-matrix` — solo `GET /health`; gateway Gotham e consumer outbox **non** implementati.

Vedi [gotham-protocol.md](../../architecture/gotham-protocol.md) per envelope, identificatori e flussi.
