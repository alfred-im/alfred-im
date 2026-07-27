# Comandi ed eventi — contesto groups

**Ultima revisione:** 2026-07-27  
**UML:** [docs/model/uml/groups/](../../model/uml/groups/)

---

## Comandi

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `ViewGroupHome` | Policy / Utente | Mostra riepilogo home del gruppo. |
| `OpenGroupConversation` | Utente | Apre storico messaggi del gruppo. |
| `BroadcastToGroup` | Utente | Invia contenuto a tutta l'allow list del gruppo. |

---

## Eventi

| Evento | Descrizione |
|--------|-------------|
| `GroupHomeReady` | Home gruppo con anteprima conversazione. |
| `GroupConversationReady` | Storico gruppo disponibile. |
| `GroupBroadcastSent` | Broadcast accettato dal server. |
| `GroupBroadcastFailed` | Broadcast non riuscito. |
| `GroupConversationUpdated` | Nuovi messaggi o aggiornamenti nello storico gruppo. |

Mapping verso eventi statechart: [README.md](./README.md).

---

## Policy

| Policy | Descrizione |
|--------|-------------|
| **Allow list bidirezionale** | Solo partecipanti con consenso reciproco ricevono copie. |
| **Un broadcast alla volta** | Nessun invio parallelo dal gruppo. |
| **Nessun invio ottimistico** | Dopo broadcast, lo storico è fonte di verità. |

---

## Confini

| Contesto | Relazione |
|----------|-----------|
| **navigation** | Shell gruppo (`OpenGroupConversation` / `LeaveGroupConversation`). |
| **delivery** | Fan-out verso partecipanti allow list (`QueueGroupFanOut`). |
| **reception** | Gate su ogni erogazione. |
