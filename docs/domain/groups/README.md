# Contesto: groups

**Stato modellazione:** `verified`

## Mapping dominio → implementazione

| Dominio | Statechart | Codice |
|---------|------------|--------|
| `ViewGroupHome` | `LoadGroupHome` | `GroupHomeMachine` |
| `OpenGroupConversation` | `InitGroupMessages` | `GroupMessagesMachine` |
| `BroadcastToGroup` | `BroadcastRequested` | `GroupArchiveService.broadcast*ToAllowlist` |
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

### Pattern coordinator (come contacts)

`GroupHomeCoordinator` / `GroupMessagesCoordinator` espongono `error` UI e orchestrano load/realtime **fuori** dalle regioni statechart. La macchina modella solo `loadState` / `broadcastState` / `realtimeState`; errori fetch e messaggi utente restano nel coordinator — **intenzionale**, non debito da unificare senza motivo.

`GroupMessagesCoordinator.loadMessages({forceRefresh})` è dettaglio implementativo del refresh post-broadcast; il modello espone solo `LoadGroupMessages` sulla macchina.

Shell navigazione gruppo (`OpenGroupConversation` / `LeaveGroupConversation`): contesto **navigation** — `navigation-shell-state.puml`.
