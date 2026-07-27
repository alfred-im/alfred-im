# Comandi ed eventi — contesto navigation

**Ultima revisione:** 2026-07-27  
**UML:** [docs/model/uml/navigation/](../../model/uml/navigation/)

---

## Comandi (dominio)

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `ShowInbox` | Utente | Mostra inbox dell'account utente in focus. |
| `OpenConversation` | Utente / Policy | Transazione unica: focus (se serve) + risolvi peer + commit scope. Sorgente: inbox, push, link, compose. |
| `CloseConversation` | Utente | Chiude chat 1:1 o gruppo; torna a inbox o home gruppo. |
| `EnterGroupShell` | Utente / Policy | Focus su account gruppo — home gruppo. |
| `OpenGroupConversation` | Utente | Apre chat del gruppo (view-state; shell resta `GroupShell`). |
| `LeaveGroupConversation` | Utente | Torna alla home gruppo da chat gruppo. |

---

## Eventi (dominio)

| Evento | Descrizione |
|--------|-------------|
| `InboxVisible` | Inbox dell'account utente in focus visibile. |
| `ConversationVisible` | Chat 1:1 aperta con peer risolto e [ConversationScope] commesso. |
| `ConversationScopeCommitted` | Ambito `(owner, peer, epoch)` registrato — messaging autorizzato. |
| `ConversationScopeInvalidated` | Ambito azzerato — messaging non mostra dati fino a nuovo commit. |
| `GroupHomeVisible` | Home gruppo visibile (`GroupShell`, `groupChatOpen = false`). |
| `GroupConversationVisible` | Chat gruppo visibile (`GroupShell`, `groupChatOpen = true`). |
| `NavigationFailed` | Peer irrisolvibile o account non disponibile. |

---

## Eventi statechart (`NavigationEvent`)

| Evento | Comando dominio | Descrizione |
|--------|-----------------|-------------|
| `SwitchToAccount` | `ShowInbox` / `EnterGroupShell` | Cambio account sidebar; invalida scope; shell inbox o gruppo. |
| `OpenPeerOnFocusedAccount` | `OpenConversation` (`inbox`) | Apre peer su account già in focus. |
| `OpenConversationOnAccount` | `OpenConversation` | Transazione completa con `OpenConversationSource`. |
| `CloseConversation` | `CloseConversation` | Chiude chat; invalida scope. |
| `OpenGroupChat` | `OpenGroupConversation` | Apre chat gruppo (view-state). |
| `BackToGroupHome` | `LeaveGroupConversation` | Torna home gruppo (view-state). |
| `MergeActivePeerFromInbox` | — | Merge metadati peer da inbox; no transizione shell. |

---

## Adapter esterni (non eventi statechart)

| Metodo adapter | `OpenConversationSource` | Policy view-state |
|----------------|--------------------------|-------------------|
| `openFromPushTap` | `push` | `clearConversationForAccount` |
| `openFromShareableLink` | `shareableLink` | `clearStaleConversationUnlessPeer` |
| `openFromCompose` | `compose` | `clearStaleConversationUnlessPeer` |

---

## Policy

| Policy | Descrizione |
|--------|-------------|
| **Un solo orchestratore** | Ogni ingresso UI passa da [NavigationMachine]. |
| **Una transazione OpenConversation** | Push, link, compose, inbox convergono sulla stessa transazione con policy per sorgente. |
| **Scope in navigation** | Solo [NavigationMachine] commette/invalida [ConversationScope]; messaging non legge `activePeer` come autorità. |
| **Focus prima della chat** | Push e link cambiano account se necessario. |
| **Nessuna chat stale** | Aprendo un peer diverso, la chat precedente si chiude e lo scope si invalida. |
| **Account gruppo** | Nessuna inbox classica — shell `GroupShell`; chat gruppo solo in view-state. |
| **Switch senza restore** | `SwitchToAccount` non ripristina chat da view-state; scope resta non commesso. |
