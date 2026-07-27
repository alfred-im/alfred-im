# Comandi ed eventi — contesto media

**Ultima revisione:** 2026-07-27  
**UML:** [docs/model/uml/media/](../../model/uml/media/)

Sotto-contesto di **messaging**: prepara allegati prima di `SendContent`. Nessuno statechart `media` in produzione — fasi UI in `ChatInputBar`, invio in `MessagesControllerEffects` / `GroupMessagesCoordinator`.

---

## Comandi

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `PrepareVoiceMessage` | Utente | Registra audio da inviare. |
| `PrepareImage` | Utente | Seleziona immagine da inviare. |
| `PrepareVideo` | Utente | Seleziona video da inviare. |
| `PrepareGif` | Utente | Seleziona GIF da inviare. |
| `PrepareLocation` | Utente | Sceglie posizione da inviare. |

---

## Eventi

| Evento | Descrizione |
|--------|-------------|
| `AttachmentReady` | Allegato pronto per l'invio. |
| `AttachmentRejected` | Formato o dimensione non validi. |
| `AttachmentCancelled` | Utente annulla la preparazione. |

---

## Policy

| Policy | Descrizione |
|--------|-------------|
| **Upload prima dell'invio** | Blob caricati prima che il messaggio parta (tranne posizione). |
| **Durata minima vocale** | Registrazioni troppo brevi vengono scartate. |
| **Rejected transitorio** | Dopo `AttachmentRejected`, feedback UI e ritorno a `Idle` senza stato persistente. |
| **Handoff a messaging** | Su `AttachmentReady`, il contesto messaging esegue `SendContent` (upload già completato o in corso con bolla ottimistica). |
