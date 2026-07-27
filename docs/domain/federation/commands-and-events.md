# Comandi ed eventi — contesto federation

**Ultima revisione:** 2026-07-27  
**UML:** [docs/model/uml/federation/](../../model/uml/federation/)

Target — bridge attualmente stub.

---

## Comandi

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `QueueFederatedSend` | Policy (invio verso esterno) | Accoda messaggio per bridge. |
| `DeliverToFederatedPeer` | Bridge | Invia verso server esterno del peer. |
| `ReceiveFromFederatedPeer` | Bridge | Riceve messaggio da server esterno. |
| `ApplyFederatedAck` | Bridge | Propaga conferme recapito/lettura esterne. |

UML platform outbound (target): [seq-federation-stub.puml](../../model/uml/federation/seq-federation-stub.puml) — `AccountBoundary` → `Outbox` : `QueueFederatedSend`; `BridgeWorker` → `FederatedServer` : `DeliverToFederatedPeer`.

Inbound federato: `BridgeWorker` → `ReceptionGate` : `EvaluateInboundDelivery` — vedi [seq-federation-inbound.puml](../../model/uml/federation/seq-federation-inbound.puml) e [seq-reception-delivery-gate.puml](../../model/uml/reception/seq-reception-delivery-gate.puml).

---

## Eventi

| Evento | Descrizione |
|--------|-------------|
| `FederatedSendQueued` | In attesa di bridge. |
| `FederatedMessageDelivered` | Server esterno ha accettato. |
| `InboundFederatedMessageReceived` | Messaggio esterno materializzato in archivio Alfred. |
| `FederatedAckApplied` | Spunte aggiornate da protocollo esterno. |

---

## Policy

| Policy | Descrizione |
|--------|-------------|
| **Bridge stateless** | Stato autorevole solo su piattaforma. |
| **Stesso modello caselle** | Copie archivio indipendenti con correlazione logica. |
| **Gate reception su inbound** | Allow list anche per messaggi federati in ingresso. |
