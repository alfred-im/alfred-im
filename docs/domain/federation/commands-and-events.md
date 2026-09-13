# Comandi ed eventi — contesto federation

**Ultima revisione:** 2026-09-13  
**UML:** [docs/model/uml/federation/](../../model/uml/federation/)  
**Amend:** peer_address — distillazione TEMP §7

Target — worker federativo non ancora implementato.

---

## Comandi

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `QueueFederatedSend` | Policy (invio verso `peer_address` con `@server` remoto) | Accoda messaggio in outbox per worker federativo. |
| `DeliverToFederatedPeer` | Worker federativo | POST verso istanza peer (`/gotham/v1/events`). |
| `ReceiveFromFederatedPeer` | Gateway federativo | Riceve envelope inbound da peer remoto. |
| `ApplyFederatedAck` | Worker federativo | Propaga conferme recapito/lettura/reazione. |
| `FetchRemoteProfile` | Policy (UI) | `get_profiles` con ramo federato (wire profilo — passo 5). |

UML platform outbound (target): [seq-federation-stub.puml](../../model/uml/federation/seq-federation-stub.puml).

Inbound federato: `FederationWorker` → `ReceptionGate` : `EvaluateInboundDelivery` — vedi [seq-federation-inbound.puml](../../model/uml/federation/seq-federation-inbound.puml).

---

## Eventi

| Evento | Descrizione |
|--------|-------------|
| `FederatedSendQueued` | In attesa di worker federativo. |
| `FederatedMessageDelivered` | Peer ha accettato (HTTP 2xx). |
| `InboundFederatedMessageReceived` | Messaggio federato materializzato in archivio Alfred con `peer_address` e `author_address` da envelope. |
| `FederatedAckApplied` | Spunte aggiornate da evento READ/deliver federato. |
| `RemoteProfileFetched` | Profilo remoto da risposta federata o fallback indirizzo. |

---

## Policy

| Policy | Descrizione |
|--------|-------------|
| **Worker stateless** | Stato autorevole solo su piattaforma (Postgres). |
| **Stesso modello caselle** | Copie archivio indipendenti con correlazione `logical_message_id`; chiave = `peer_address`. |
| **Gate reception su inbound** | Allow list su `allowed_address` anche per messaggi federati in ingresso. |
| **Nessuna tipologia chat** | Federato e locale: stessa UI, stesso modello account — routing solo in delivery. |
| **author_address copia mittente** | Scrivendo all'esterno: forma FQDN sulla copia mittente — vedi PROM-CHAT-PEER-KEY §3. |
