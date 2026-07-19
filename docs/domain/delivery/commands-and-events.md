# Comandi ed eventi — contesto delivery

**Ultima revisione:** 2026-07-19  
**UML:** [docs/model/uml/delivery/](../../model/uml/delivery/)  
**Nota:** nessuno statechart client — solo sequenze worker.

---

## Comandi (accodamento da RPC account)

| Comando | Emesso da | Tipo outbox | Descrizione |
|---------|-----------|-------------|-------------|
| `EnqueueDeliver` | Policy (invio messaggio) | `deliver` | Accoda recapito copia mittente verso destinatario. |
| `EnqueueGroupErogate` | Policy (broadcast gruppo) | `group_erogate` | Accoda erogazione fan-out da archivio gruppo. |
| `EnqueueReadReceipt` | Policy (mark read) | `read_receipt` | Accoda propagazione spunta lettura al mittente. |

Ogni accodamento attiva il worker nella stessa transazione (internal).

---

## Comandi worker

| Comando | Descrizione |
|---------|-------------|
| `ProcessOutbox` | Legge tipo evento outbox e delega all'handler. |
| `DeliverInternal` | Applica gate reception e materializza copia destinatario. |
| `GroupErogate` | Fan-out da riga archivio gruppo. |
| `ErogateGroupMessage` | Eroga messaggio a ogni partecipante allow list. |
| `ProcessReadReceipt` | Propaga `read_at` sulla copia mittente. |
| `PropagateReadReceipt` | Aggiorna spunta lettura sul messaggio originale. |
| `CompleteOutbox` | Marca outbox completata. |

---

## Eventi

| Evento | Descrizione |
|--------|-------------|
| `OutboxQueued` | Evento accodato per elaborazione asincrona. |
| `DeliveryGatePassed` | Mittente autorizzato per recapito al destinatario. |
| `DeliveryGateRejected` | Gate fallito; nessuna copia destinatario. |
| `RecipientCopyMaterialized` | Copia destinatario creata in archivio. |
| `SenderDeliveredAtSet` | Spunta doppia valorizzata su copia mittente. |
| `GroupArchiveUpdated` | Messaggio inserito in storico gruppo. |
| `ParticipantCopyErogated` | Copia proxy su archivio partecipante. |
| `ReadAtPropagated` | Spunta lettura propagata al mittente. |
| `OutboxCompleted` | Handler terminato con successo. |
| `PushNotifyEnqueued` | Push accodata post-recapito riuscito. |

---

## Policy

| Policy | Trigger | Azione |
|--------|---------|--------|
| **Gate before deliver** | `ProcessOutbox` tipo deliver | Valuta allow list destinatario prima di INSERT. |
| **Bidirectional group gate** | Mittente o destinatario è gruppo | Allow list richiesta in entrambe le direzioni. |
| **Auto-erogate on group receive** | Messaggio umano in storico gruppo | Erogazione nella stessa transazione. |
| **Silent skip erogation** | Partecipante non passa gate | Nessun effetto su spunte originali. |
| **No cross-boundary write** | Qualsiasi RPC account | Vietato scrivere su archivio altrui. |

---

## Stati operativi outbox

| Stato | Significato |
|-------|-------------|
| `queued` | In attesa di consumer. |
| `processing` | (futuro async) Consumer ha claimato la riga. |
| `completed` | Handler terminato (anche su rejection silenziosa). |
| `failed` | Errore transazione; ultimo errore registrato. |

Su internal sincrono, transizione `queued` → `completed` è atomica nella RPC account.

---

## Tracciabilità SDD

| Elemento | Promessa |
|----------|----------|
| Outbox bus, event_kind | SYS-DELIVERY-001–009 |
| Worker schema e handler | SYS-DELIVERY-010–017 |
| Spunte via worker | SYS-DELIVERY-018–020 |
| Gate in deliver | SYS-RECEPTION + SYS-DELIVERY-012 |
| Gruppo / erogazione | SYS-GROUP-015–026 |
