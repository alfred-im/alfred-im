# Comandi ed eventi — contesto messaging

**Ultima revisione:** 2026-07-19  
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

---

## Eventi

| Evento | Descrizione |
|--------|-------------|
| `ConversationReady` | Storico disponibile; conversazione utilizzabile. |
| `ConversationUnavailable` | Sessione non valida o caricamento fallito. |
| `ContentSent` | Invio accettato dal server. |
| `ContentSendFailed` | Invio non riuscito; resta in coda retry. |
| `ConversationUpdated` | Nuovi messaggi, pagina storico precedente caricata, o aggiornamento spunte in conversazione. |

---

## Policy

| Policy | Descrizione |
|--------|-------------|
| **Un messaggio, una bolla** | Stesso messaggio logico non duplica in UI. |
| **Invio serializzato** | Un invio alla volta per conversazione. |
| **Segna letto all'apertura** | Aprendo la chat, i messaggi del peer sono letti. |
| **Sincronizzazione realtime** | Mentre la chat è aperta, gli aggiornamenti arrivano in tempo reale. |
| **Retry automatico** | Invii falliti riprovati con backoff finché in coda. |

---

## Confini

| Contesto | Relazione |
|----------|-----------|
| **navigation** | Apre/chiude la conversazione (`OpenConversation`). |
| **media** | Preparazione allegati prima di `SendContent`. |
| **delivery** | Recapito e spunte lato server. |
| **reception** | Gate allow list sul recapito (non blocca invio al mittente). |
