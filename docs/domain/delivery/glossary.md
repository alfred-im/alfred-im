# Glossario — contesto delivery

**Bounded context:** `delivery`  
**Ultima revisione:** 2026-07-19  
**Promesse SDD:** [SYS-DELIVERY](../../specs/promises/system/SYS-DELIVERY.md), [SYS-ACCOUNT-BOUNDARY](../../specs/promises/system/SYS-ACCOUNT-BOUNDARY.md)

---

## Linguaggio ubiquo

| Termine | Definizione |
|---------|-------------|
| **Delivery plane** | Infrastruttura non-account: schema `alfred_delivery`, worker SQL, unico attraversamento confine tra archivi. |
| **Outbox** | Tabella `outbox` — bus eventi; ogni invio account e ogni `read_receipt` accoda una riga `status = queued`. |
| **event_kind** | Discriminatore payload: `deliver`, `read_receipt`, `group_erogate`, `push_notify` (SYS-PUSH). |
| **process_outbox** | Dispatcher: instrada per `event_kind` verso handler dedicato. |
| **deliver_internal** | Recapito 1:1 o verso archivio gruppo; gate reception; INSERT copia destinatario; UPDATE `delivered_at` mittente. |
| **group_erogate** | Handler broadcast: legge riga archivio gruppo e invoca `erogate_group_message`. |
| **erogate_group_message** | Fan-out verso partecipanti allow list del gruppo con gate per-partecipante. |
| **propagate_read_receipt** | UPDATE `read_at` sulla copia mittente identificata da `logical_message_id`. |
| **Synchronous internal** | Su internal, `process_outbox` nella **stessa transazione** della RPC account — utente vede esito immediato. |
| **reception_rejected** | Flag in payload outbox quando gate allow list nega recapito; `delivered_at` mittente resta null. |
| **logical_message_id (λ)** | Correlazione tra copie mittente/destinatario e target segnali spunta. |
| **Idempotenza destinatario** | `ON CONFLICT (owner_id, logical_message_id) DO NOTHING` su INSERT copia. |
| **queue_status** | `queued` → `completed` (o `failed` con `last_error` su errore transazione). |
| **Tick spunta** | UPDATE `delivered_at` / `read_at` sulla copia mittente — osservabile via Realtime client. |

---

## Confini

| Contesto | Relazione |
|----------|-----------|
| **messaging** | RPC account creano solo copia mittente + accodano outbox; non INSERT cross-boundary. |
| **reception** | `is_sender_allowed_for_reception` valutato **solo** nel worker prima di materializzare destinatario. |
| **groups** | Branch gruppo in `deliver_internal`; `group_erogate` + `erogate_group_message` per broadcast/erogazione. |
| **federation** | Stesso outbox; `protocol = xmpp|matrix` → consumer bridge (stub) invece di sync internal. |
| **notifications** | Post-recapito: `push_notify` accodato da worker (SYS-PUSH). |

---

## Invarianti

1. Nessun `GRANT EXECUTE` su funzioni `alfred_delivery.*` al ruolo `authenticated`.
2. Worker non usa `auth.uid()` — opera come `SECURITY DEFINER` infrastruttura.
3. Rifiuto allow list: outbox `completed` con `reception_rejected: true` — **nessun** errore RPC verso mittente.
4. `delivered_at` valorizzato solo se copia destinatario (o storico gruppo) materializzata con successo.
5. Erogazione verso partecipante fallita (gate): skip silenzioso — non aggiorna spunte del mittente originale umano.
6. `read_receipt`: lettore aggiorna solo proprio archivio; worker propaga `read_at` al mittente.
