# Glossario — contesto delivery

**Bounded context:** `delivery`  
**Ultima revisione:** 2026-07-27  
**Promesse SDD:** [SYS-DELIVERY](../../specs/promises/system/SYS-DELIVERY.md), [SYS-ACCOUNT-BOUNDARY](../../specs/promises/system/SYS-ACCOUNT-BOUNDARY.md)

---

## Linguaggio ubiquo

| Termine | Definizione |
|---------|-------------|
| **Delivery plane** | Infrastruttura worker che attraversa il confine tra archivi mailbox — unico punto autorizzato oltre il confine account. |
| **Outbox** | Bus eventi di recapito; ogni invio account e ogni read receipt accoda un evento `queued`. |
| **Event kind** | Discriminatore payload: `deliver`, `read_receipt`, `group_erogate`, `push_notify` (SYS-PUSH). |
| **Delivery worker** | Dispatcher che instrada per `event_kind` verso handler dedicato (`ProcessDeliveryQueue`). |
| **DeliverInternal** | Recapito 1:1 o verso archivio gruppo; gate reception; materializza copia destinatario; aggiorna spunta mittente. |
| **GroupErogate** | Handler broadcast: legge riga archivio gruppo e avvia erogazione fan-out. |
| **ErogateGroupMessage** | Fan-out verso partecipanti allow list del gruppo con gate per-partecipante. |
| **PropagateReadReceipt** | Propaga spunta lettura sulla copia mittente identificata da id logico messaggio (λ). |
| **ProcessPushNotification** | Handler evento `push_notify`: invoca pipeline Web Push (SYS-PUSH). |
| **Synchronous internal** | Su protocollo internal, worker eseguito nella **stessa transazione** del confine account — esito immediato per l'utente. |
| **DeliverySilentlyBlocked** | Esito gate allow list negato; spunta doppia mittente non valorizzata; nessun errore verso mittente (termine condiviso con reception). |
| **Logical message id (λ)** | Correlazione tra copie mittente/destinatario e target segnali spunta. |
| **Recipient idempotency** | Materializzazione copia destinatario idempotente per coppia owner + id logico. |
| **Queue status** | `queued` → `completed` (o `failed` con ultimo errore registrato). |
| **Delivery tick** | Aggiornamento spunte sulla copia mittente — osservabile via Realtime client. |
| **Account boundary** | Confine operazioni account: crea solo copia mittente e accoda outbox; non scrive archivi altrui. |
| **Bidirectional gate** | Per destinatario gruppo: entrambe le direzioni allow list devono consentire il recapito. |

---

## Confini

| Contesto | Relazione |
|----------|-----------|
| **messaging** | Confine account crea solo copia mittente + accoda outbox; nessuna scrittura cross-boundary. |
| **reception** | Gate allow list valutato **solo** nel worker (`EvaluateInboundDelivery`) prima di materializzare destinatario. |
| **groups** | Branch gruppo in `DeliverInternal`; `GroupErogate` + `ErogateGroupMessage` per broadcast/erogazione. |
| **federation** | Stesso outbox; protocollo esterno → consumer bridge (stub) invece di sync internal. |
| **notifications** | Post-recapito: `QueuePushNotification` dal worker (SYS-PUSH). |

---

## Invarianti

1. Worker delivery non invocabile direttamente dal client autenticato.
2. Worker opera come infrastruttura privilegiata — non dipende da sessione utente corrente.
3. Rifiuto allow list: outbox `completed` con esito `DeliverySilentlyBlocked` — **nessun** errore verso mittente.
4. Spunta doppia valorizzata solo se copia destinatario (o storico gruppo) materializzata con successo.
5. Erogazione verso partecipante fallita (gate): skip silenzioso — non aggiorna spunte del mittente originale umano.
6. Read receipt: lettore aggiorna solo proprio archivio; worker propaga spunta lettura al mittente.
7. Push: `QueuePushNotification` solo dopo materializzazione copia destinatario (SYS-DELIVERY-022).
