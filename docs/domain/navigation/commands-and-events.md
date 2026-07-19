# Comandi ed eventi — contesto navigation

**Ultima revisione:** 2026-07-19  
**UML:** [docs/model/uml/navigation/](../../model/uml/navigation/)

---

## Comandi

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `ShowInbox` | Utente | Mostra inbox dell'account in focus. |
| `OpenConversation` | Utente / Policy | Transazione unica: focus (se serve) + risolvi peer + commit scope. Sorgente: inbox, push, link, compose. |
| `CloseConversation` | Utente | Chiude chat; torna a inbox o home gruppo. |
| `EnterGroupShell` | Utente / Policy | Focus su account gruppo — home gruppo. |
| `OpenGroupConversation` | Utente | Apre chat del gruppo. |
| `LeaveGroupConversation` | Utente | Torna alla home gruppo da chat gruppo. |

---

## Eventi

| Evento | Descrizione |
|--------|-------------|
| `InboxVisible` | Inbox dell'account in focus visibile. |
| `ConversationVisible` | Chat 1:1 aperta con peer risolto e [ConversationScope] commesso. |
| `ConversationScopeCommitted` | Ambito `(owner, peer, epoch)` registrato — messaging autorizzato. |
| `ConversationScopeInvalidated` | Ambito azzerato — messaging non mostra dati fino a nuovo commit. |
| `GroupHomeVisible` | Home gruppo visibile. |
| `GroupConversationVisible` | Chat gruppo visibile. |
| `NavigationFailed` | Peer irrisolvibile o account non disponibile. |

---

## Policy

| Policy | Descrizione |
|--------|-------------|
| **Un solo orchestratore** | Ogni ingresso UI passa da [NavigationMachine]. |
| **Una transazione OpenConversation** | Push, link, compose, inbox convergono sulla stessa transazione con policy per sorgente. |
| **Scope in navigation** | Solo [NavigationMachine] commette/invalida [ConversationScope]; messaging non legge `activePeer` come autorità. |
| **Focus prima della chat** | Push e link cambiano account se necessario. |
| **Nessuna chat stale** | Aprendo un peer diverso, la chat precedente si chiude e lo scope si invalida. |
| **Account gruppo** | Nessuna inbox classica — shell gruppo dedicata. |
