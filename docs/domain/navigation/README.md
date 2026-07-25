# Contesto: navigation

**Stato modellazione:** `verified`

## Mapping dominio → implementazione

### Comandi

| Dominio | Statechart | Codice |
|---------|------------|--------|
| `ShowInbox` | `SwitchToAccount` / `InboxVisible` | `NavigationMachine` |
| `OpenConversation` | `OpenPeerOnFocusedAccount`, `OpenConversationOnAccount`, `OpenFromPushTap`, `OpenFromShareableLink`, `OpenFromCompose` | adapter per ingresso; **consolida sessione** prima di `commitScope` |
| `CloseConversation` | `CloseConversation` | `NavigationMachine` |
| `EnterGroupShell` | `SwitchToAccount` [gruppo] | `GroupShell` |
| `OpenGroupConversation` | `OpenGroupChat` | shell gruppo |
| `LeaveGroupConversation` | `BackToGroupHome` | shell gruppo |

### Stati shell (UML ↔ `NavigationShellState`)

| UML / glossario | `NavigationShellState` |
|-----------------|--------------------------|
| `InboxVisible` | `inboxVisible` |
| `ChatOpen` | `chatOpen` |
| `GroupShell` | `groupShell` |

Statechart: `client/lib/machines/navigation/` · `NavigationCoordinator`
