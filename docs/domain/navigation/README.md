# Contesto: navigation

**Stato modellazione:** `verified`

**Invarianti:** [invariants.md](invariants.md)

## Mapping dominio → implementazione

### Comandi dominio → eventi statechart

| Comando dominio | Evento `NavigationMachine` | Note |
|-----------------|------------------------------|------|
| `ShowInbox` | `SwitchToAccount` | Account utente in focus; invalida scope; evento `InboxVisible`. |
| `EnterGroupShell` | `SwitchToAccount` | Account gruppo in focus; invalida scope; evento `GroupHomeVisible`. |
| `OpenConversation` | `OpenPeerOnFocusedAccount` | Inbox su account già in focus (`source=inbox`). |
| `OpenConversation` | `OpenConversationOnAccount` | Transazione completa (focus + consolidate + resolve + commit). |
| `CloseConversation` | `CloseConversation` | Utente → inbox; gruppo → home gruppo (via effetti). |
| `OpenGroupConversation` | `OpenGroupChat` | Shell resta `groupShell`; view-state `groupChatOpen`. |
| `LeaveGroupConversation` | `BackToGroupHome` | Shell resta `groupShell`; view-state home gruppo. |

### Adapter esterni (altri contesti → `OpenConversation`)

Non sono eventi statechart: convergono su `OpenConversationOnAccount` con `OpenConversationSource`.

| Ingresso adapter | `OpenConversationSource` | Contesto sorgente |
|------------------|--------------------------|-------------------|
| `openFromPushTap` | `push` | notifications |
| `openFromShareableLink` | `shareableLink` | shareable-link |
| `openFromCompose` | `compose` | contacts / compose |

Implementazione: `NavigationAdapters` · `ExternalIntentAdapter` · `NavigationCoordinator`.

### Evento interno (nessun comando dominio)

| Evento statechart | Scopo |
|-------------------|-------|
| `MergeActivePeerFromInbox` | Aggiorna metadati `activePeer` da riga inbox; non cambia shell né scope. |

### Stati shell (UML ↔ `NavigationShellState`)

| UML / glossario | `NavigationShellState` | `committedScope` |
|-----------------|--------------------------|------------------|
| `InboxVisible` | `inboxVisible` | `null` |
| `ChatOpen` | `chatOpen` | `(owner, peer, epoch)` |
| `GroupShell` | `groupShell` | `null` (chat gruppo = view-state `groupChatOpen`) |

Eventi osservabili correlati: `InboxVisible`, `ConversationVisible`, `GroupHomeVisible`, `GroupConversationVisible` — vedi [commands-and-events.md](commands-and-events.md).

Statechart: `client/lib/machines/navigation/` · `NavigationCoordinator`
