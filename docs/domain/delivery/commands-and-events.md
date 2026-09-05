# Comandi ed eventi — contesto delivery

**Ultima revisione:** 2026-09-05  
**UML:** [docs/model/uml/delivery/](../../model/uml/delivery/)

Worker server — nessuno statechart client.

---

## Comandi — accodamento (confine account)

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `QueueDelivery` | Policy (invio account) | Accoda recapito messaggio al destinatario. |
| `QueueReadReceipt` | Policy (lettura) | Accoda propagazione spunta lettura (con `read_receipt_id`) al mittente. |
| `QueueGroupFanOut` | Policy (broadcast gruppo) | Accoda erogazione verso partecipanti. |
| `QueueReactionFact` | Policy (reaction account) | Accoda persistenza append-only reaction (`event_kind = reaction_fact`). |

---

## Comandi — worker (platform)

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `ProcessDeliveryQueue` | Policy (worker) | Elabora prossimo evento in coda (dispatcher per `event_kind`). |
| `DeliverInternal` | `ProcessDeliveryQueue` | Recapito 1:1 o verso archivio gruppo; gate reception prima della materializzazione. |
| `PropagateReadReceipt` | `ProcessDeliveryQueue` | Propaga spunta lettura e `read_receipt_id` sulla copia mittente (λ). |
| `GroupErogate` | `ProcessDeliveryQueue` | Legge archivio gruppo e avvia fan-out. |
| `ErogateGroupMessage` | `DeliverInternal` / `GroupErogate` | Erogazione verso partecipanti allow list con gate per-partecipante. |
| `QueuePushNotification` | Policy post-recapito | Accoda notifica Web Push post-recapito riuscito (SYS-PUSH). |
| `ProcessPushNotification` | `ProcessDeliveryQueue` | Invoca pipeline Web Push per evento `push_notify`. |
| `ProcessReactionFact` | `ProcessDeliveryQueue` | INSERT append-only su `message_reaction_facts` per evento `reaction_fact`. |

---

## Eventi

| Evento | Descrizione |
|--------|-------------|
| `RecipientNotified` | Copia destinatario materializzata; spunta doppia mittente valorizzata se consentito. |
| `DeliveryCompleted` | Evento in coda elaborato (`completed`). |
| `ReadReceiptPropagated` | Spunta lettura visibile al mittente. |
| `GroupFanOutCompleted` | Erogazione gruppo terminata. |
| `DeliverySilentlyBlocked` | Gate reception negato — nessuna copia destinatario; nessun errore verso mittente (evento reception, osservato nel worker). |

---

## Policy

| Policy | Descrizione |
|--------|-------------|
| **Gate reception prima del recapito** | Allow list valutata sul destinatario (`EvaluateInboundDelivery`). |
| **Nessuna scrittura cross-archivio** | Solo il worker attraversa il confine tra archivi. |
| **Rifiuto silenzioso** | Gate fallito → `DeliverySilentlyBlocked`; nessun errore verso il mittente. |
| **Push solo dopo materializzazione** | `QueuePushNotification` solo se copia destinatario creata (SYS-DELIVERY-022). |
