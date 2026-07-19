# Comandi ed eventi — contesto messaging

**Ultima revisione:** 2026-07-19  
**UML:** [docs/model/uml/messaging/](../../model/uml/messaging/)

---

## Comandi (intento)

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `LoadMessages` | Policy (apertura conversazione) | Carica storico messaggi del peer aperto. |
| `ReloadMessages` | Utente | Aggiorna la lista messaggi. |
| `MarkRead` | Policy (apertura conversazione) | Segna come letti i messaggi del peer aperto. |
| `AttachRealtime` | Policy (post-load) | Attiva aggiornamenti realtime sulla conversazione. |
| `DetachRealtime` | Policy (chiusura conversazione) | Disattiva sottoscrizione realtime. |
| `SendMessage` | Utente | Invia contenuto testuale. |
| `SendGif` | Utente | Invia GIF. |
| `SendVoice` | Utente | Invia messaggio vocale — vedi contesto **media**. |
| `SendLocation` | Utente | Invia posizione — vedi contesto **media**. |
| `SendImage` | Utente | Invia immagine — vedi contesto **media**. |
| `SendVideo` | Utente | Invia video — vedi contesto **media**. |
| `RetryMessage` | Utente | Ritenta invio di un messaggio fallito. |
| `ProcessOutboundRetries` | Policy (timer) | Riprocessa la coda outbound con backoff. |
| `RestoreFailedOutbound` | Policy (post-load) | Reidrata messaggi falliti dalla coda persistente. |

---

## Eventi

| Evento | Descrizione |
|--------|-------------|
| `MessagesLoaded` | Storico conversazione disponibile. |
| `LoadFailed` | Caricamento fallito; errore esposto all'utente. |
| `SessionExpired` | Sessione non valida — nessun load né invio. |
| `OptimisticInserted` | Messaggio pending inserito in lista prima dell'ACK. |
| `SendAcknowledged` | Invio confermato dal server; merge con riga archivio. |
| `SendFailed` | Invio fallito; messaggio marcato failed in coda. |
| `RealtimeReceived` | Nuovo messaggio o aggiornamento contenuto da realtime. |
| `DeliveryTickReceived` | Aggiornamento sole spunte su messaggio mittente. |
| `RetryDispatched` | Tentativo retry outbound completato o fallito. |
| `InboxRefreshRequested` | Richiesta aggiornamento anteprima inbox dopo invio riuscito. |

---

## Policy

| Policy | Trigger | Azione |
|--------|---------|--------|
| **Init conversazione** | Apertura chat | `LoadMessages` → `RestoreFailedOutbound` → `MarkRead` → `AttachRealtime` → avvio timer retry. |
| **Invio serializzato** | `Send*` in corso | Blocca invii paralleli e retry automatici nella stessa conversazione. |
| **Merge senza duplicati** | `RealtimeReceived` o ACK | Una sola bolla per `client_message_id`; preserva media su tick-only. |
| **Sessione scaduta** | `SessionExpired` | Nessun load né send; errore sessione all'utente. |
| **Realtime per focus** | Cambio account in focus | Solo conversazione dell'account attivo resta sottoscritta. |

---

## Sistemi esterni

| Sistema | Ruolo |
|---------|------|
| **Supabase** | RPC mailbox, storage media, canale Realtime owner. |
| **Coda outbound persistente** | Retry messaggi e media dopo fallimento rete/upload. |

---

## Tracciabilità SDD

| Elemento | Promessa |
|----------|----------|
| Coda + optimistic | PROM-OUTBOUND-SEND |
| Spunte post-ACK | PROM-MESSAGE-STATUS |
| Realtime owner + peer | PROM-REALTIME-OWNER |
| Media upload | PROM-CHAT-MEDIA (sotto-contesto media) |
