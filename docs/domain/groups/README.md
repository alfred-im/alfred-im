# Contesto: groups

**Stato modellazione:** `verified`

## Mapping dominio → implementazione

| Dominio | Statechart | Codice |
|---------|------------|--------|
| `ViewGroupHome` | `LoadGroupHome` | `GroupHomeMachine` |
| `OpenGroupConversation` | `InitGroupMessages` | `GroupMessagesMachine` |
| `BroadcastToGroup` | `BroadcastRequested` | `MessageService.broadcast*ToAllowlist` |
| `GroupHomeReady` | `GroupHomeLoaded` | `GroupHomeCoordinator` |
| `GroupConversationReady` | `GroupMessagesLoaded` | `GroupMessagesCoordinator` |
| `GroupBroadcastSent` | `BroadcastAcknowledged` | reload storico owner |
| `GroupBroadcastFailed` | `BroadcastFailed` | errore in `GroupMessagesUiState.error` |
| `GroupConversationUpdated` | `OwnerRealtimeReceived` | realtime archivio owner |

### Eventi statechart (solo client)

| Statechart | Descrizione |
|------------|-------------|
| `LoadGroupMessages` | Refresh storico senza ri-attach realtime |
| `GroupHomeLoadFailed` / `GroupMessagesLoadFailed` | Errore load → regione `Ready` (come contacts) |
| `DisposeGroupMessages` | Detach realtime alla chiusura conversazione |

Statechart: `client/lib/machines/groups/` · `GroupHomeCoordinator`, `GroupMessagesCoordinator`

Shell navigazione gruppo (`OpenGroupConversation` / `LeaveGroupConversation`): contesto **navigation** — `navigation-shell-state.puml`.
