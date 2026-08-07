# Comandi ed eventi — contesto messaging

**Ultima revisione:** 2026-08-07  
**UML:** [docs/model/uml/messaging/](../../model/uml/messaging/)

---

## Comandi

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `OpenConversation` | Policy (navigazione apre chat) | Carica e sincronizza la conversazione con il peer. |
| `SendContent` | Utente | Invia testo, media o posizione al peer. |
| `RetryFailedSend` | Utente | Ritenta un invio fallito. |
| `RefreshConversation` | Utente | Aggiorna lo storico messaggi (finestra recente). |
| `LoadOlderMessages` | Utente (scroll verso l'alto) | Carica la pagina precedente dello storico senza cambiare il messaggio visibile. |
| `OpenMessageActions` | Utente (tap su messaggio) | Apre il menu azioni sul messaggio target. |
| `CloseMessageActions` | Utente / policy UI | Chiude il menu azioni. |
| `ApplyReaction` | Utente | Registra un fatto `applied` su `logical_message_id` con emoji scelta. |
| `WithdrawReaction` | Utente | Registra un fatto `withdrawn` su `logical_message_id` (nessuna emoji nel fatto). |

---

## Dati — `MessageReactionFact`

Fatto immutabile (append-only). Vedi glossario: [glossary.md](./glossary.md).

| Campo | Tipo | Note |
|-------|------|------|
| `id` | uuid | Identità del fatto |
| `logicalMessageId` | uuid | λ del messaggio target |
| `reactorId` | uuid | Chi compie l'azione |
| `kind` | `applied` \| `withdrawn` | |
| `emoji` | string? | Obbligatorio se `applied`; assente se `withdrawn` |
| `occurredAt` | timestamptz | Data dell'azione |

**Stato corrente (derivato):** per ogni `(logicalMessageId, reactorId)`, ultimo fatto per `occurredAt` (tie-break `id`). Se `applied` → quell'emoji è attiva; se `withdrawn` → nessuna reaction attiva.

**Aggregato bolla (derivato):** `ReactionSummary` — raggruppa gli stati correnti per `emoji` (`count`, `includesMe`).

---

## Eventi

| Evento | Descrizione |
|--------|-------------|
| `ConversationReady` | Storico disponibile; conversazione utilizzabile. |
| `ConversationUnavailable` | Sessione non valida o scope non commesso; conversazione bloccata fino a refresh. |
| `ContentSent` | Invio accettato dal server. |
| `ContentSendFailed` | Invio non riuscito; resta in coda retry. |
| `ConversationUpdated` | Nuovi messaggi, pagina storico precedente caricata, aggiornamento spunte (realtime), o nuovi fatti reaction in conversazione. |
| `MessageActionsOpened` | Menu azioni visibile su un messaggio target. |
| `MessageActionsClosed` | Menu azioni chiuso. |
| `ReactionApplied` | Fatto `applied` persistito (o accettato in coda optimistic). |
| `ReactionWithdrawn` | Fatto `withdrawn` persistito (o accettato in coda optimistic). |

---

## Policy

| Policy | Descrizione |
|--------|-------------|
| **Un messaggio, una bolla** | Stesso messaggio logico non duplica in UI. |
| **Invio serializzato** | Un invio alla volta per conversazione. |
| **Segna letto all'apertura** | Aprendo la chat, i messaggi del peer sono letti. |
| **Sincronizzazione realtime** | Mentre la chat è aperta, gli aggiornamenti arrivano in tempo reale. |
| **Retry automatico** | Invii falliti riprovati con backoff finché in coda. |
| **Reaction solo su λ** | `ApplyReaction` / `WithdrawReaction` richiedono `logical_message_id` noto — messaggio in attesa (pre-ACK) escluso. |
| **Reaction append-only** | Ogni comando reaction produce un nuovo `MessageReactionFact`; cambio emoji = nuovo `applied`, non mutazione del fatto precedente. |
| **Una reaction attiva per utente** | Stato corrente: al massimo un'emoji attiva per `(logical_message_id, reactor_id)`; `WithdrawReaction` chiude lo slot. |
| **Idempotenza UI** | `ApplyReaction` con emoji già attiva, o `WithdrawReaction` senza reaction attiva: nessun nuovo fatto (no-op lato dominio). |

---

## Confini

| Contesto | Relazione |
|----------|-----------|
| **navigation** | Apre/chiude la conversazione (`OpenConversation`). |
| **media** | Preparazione allegati prima di `SendContent`. |
| **delivery** | Recapito e spunte lato server. |
| **reception** | Gate allow list sul recapito (non blocca invio al mittente). |
