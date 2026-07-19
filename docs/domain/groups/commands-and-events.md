# Comandi ed eventi — contesto groups

**Ultima revisione:** 2026-07-19  
**UML:** [docs/model/uml/groups/](../../model/uml/groups/)

---

## Comandi — home gruppo

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `LoadGroupHome` | Policy (init / refresh) | Carica riepilogo home: conteggi, autori attivi, tile conversazione. |
| `BuildConversationTile` | Policy (post-load) | Deriva anteprima conversazione dallo storico gruppo. |
| `BuildActiveAuthors` | Policy (post-load) | Aggrega autori umani attivi nello storico. |

---

## Comandi — conversazione gruppo

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `InitGroupMessages` | Policy (apertura chat gruppo) | Avvia ciclo di vita conversazione gruppo. |
| `LoadGroupMessages` | Policy (init / refresh) | Carica storico archivio gruppo. |
| `AttachOwnerRealtime` | Policy (post-load) | Sottoscrive aggiornamenti sull'archivio owner del gruppo. |
| `BroadcastRequested` | Utente | Invia contenuto (testo, media, posizione) a tutta l'allow list. |
| `DisposeGroupMessages` | Policy (chiusura chat) | Termina sottoscrizione realtime gruppo. |

---

## Comandi — navigazione shell gruppo

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `OpenGroupChat` | Utente | Apre conversazione gruppo dalla home. |
| `BackToGroupHome` | Utente | Torna alla home gruppo da chat aperta. |
| `RefreshGroupHome` | Policy (post-broadcast) | Aggiorna riepilogo home dopo invio riuscito. |

---

## Eventi

| Evento | Descrizione |
|--------|-------------|
| `GroupHomeLoaded` | Home gruppo pronta. |
| `GroupHomeLoadFailed` | Caricamento home fallito. |
| `GroupMessagesLoaded` | Storico gruppo disponibile. |
| `GroupMessagesLoadFailed` | Caricamento storico fallito. |
| `BroadcastAcknowledged` | Broadcast confermato dal server. |
| `BroadcastFailed` | Broadcast fallito. |
| `OwnerRealtimeReceived` | Nuovo messaggio o aggiornamento su archivio gruppo. |
| `AuthorNamesEnriched` | Etichette autore disponibili per messaggi gruppo. |

---

## Policy

| Policy | Trigger | Azione |
|--------|---------|--------|
| **Broadcast serializzato** | `BroadcastRequested` in corso | Nessun secondo broadcast parallelo. |
| **Nessun optimistic** | Broadcast riuscito | Ricarica storico — nessuna bolla pending client. |
| **Refresh home** | `BroadcastAcknowledged` | `RefreshGroupHome` |
| **Gate allow list** | Recapito / erogazione | Solo partecipanti con consenso bidirezionale ricevono copie. |

---

## Sistemi esterni

| Sistema | Ruolo |
|---------|------|
| **Supabase** | RPC broadcast, storico owner, Realtime archivio gruppo. |
| **delivery** | Fan-out erogazione verso partecipanti allow list. |

Dettaglio sequenze worker: contesto **delivery** e [SYS-GROUP](../../specs/promises/system/SYS-GROUP.md).

---

## Tracciabilità SDD

| Elemento | Promessa |
|----------|----------|
| Account gruppo, allow list, erogazione | SYS-GROUP |
| Outbox gruppo, worker | SYS-DELIVERY |
| Shell senza inbox, autore in bolla | SURF-GROUP-*, PROM-GROUP-AUTHOR-DISPLAY |
