# Glossario — contesto messaging

**Bounded context:** `messaging`  
**Ultima revisione:** 2026-07-19  
**Promesse SDD:** [PROM-OUTBOUND-SEND](../../specs/promises/product/PROM-OUTBOUND-SEND.md), [PROM-MESSAGE-STATUS](../../specs/promises/product/PROM-MESSAGE-STATUS.md), [PROM-REALTIME-OWNER](../../specs/promises/product/PROM-REALTIME-OWNER.md)

---

## Linguaggio ubiquo

| Termine | Definizione |
|---------|-------------|
| **Mailbox archive** | Copia messaggio nell'archivio dell'utente corrente; ogni utente vede solo la propria copia. |
| **Peer conversation** | Scambio 1:1 (o gruppo) tra utente corrente e peer; storico caricato per coppia owner–peer. |
| **Chat message** | Messaggio in conversazione: corpo, media, coordinate, stato spunte, identificatore client. |
| **Optimistic message** | Messaggio pending inserito lato client prima della conferma server. |
| **Client message id** | Identificatore client per idempotenza; chiave di merge tra optimistic e riga server. |
| **Outbound queue** | Coda persistente per retry dopo fallimento rete o upload media. |
| **Queue scope** | Ambito coda per account e peer ([PROM-OUTBOUND-SEND-002]). |
| **Message merge** | Unione riga realtime/RPC in bolla esistente senza perdere media né payload retry. |
| **Tick-only update** | Aggiornamento realtime con sole date spunte — merge preserva contenuto e media. |
| **Sender message** | Messaggio scritto dall'utente corrente — abilita spunte mittente ([PROM-MESSAGE-STATUS-010]). |
| **Message status** | `pending`/`failed` solo pre-ACK client; post-ACK derivato dall'archivio mailbox. |
| **Realtime owner filter** | Sottoscrizione su archivio dell'utente corrente; peer filtrato in elaborazione. |
| **Delivery tick** | Aggiornamento spunte sulla copia mittente quando il recapito avanza. |
| **Retry backoff** | Ritardo crescente tra tentativi retry (cap massimo, timer periodico). |
| **Pending media preview** | Anteprima media locale prima che l'URL pubblico sia disponibile. |

---

## Confini

| Contesto | Relazione |
|----------|-----------|
| **media** | Upload blob prima dell'invio per tipi con allegato. |
| **delivery** | Worker server valorizza spunte sulla copia mittente. |
| **reception** | Recapito bloccato se allow list fallisce — non errore invio al mittente. |
| **multi-account** | Conversazione e coda scoped all'account in focus; realtime solo per focus attivo. |
| **navigation** | Apertura chat avvia il ciclo di vita della conversazione per (account, peer). |

---

## Invarianti

1. Una sola bolla per `client_message_id` — merge su id incrociati.
2. Un solo invio (o retry automatico) alla volta nella stessa conversazione.
3. All'apertura: load → restore coda → mark read → attach realtime → timer retry.
4. Realtime non duplica messaggi già presenti — merge in place.
5. Sessione scaduta: nessun load né send.
