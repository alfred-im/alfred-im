# Contesto: messaging

**Stato modellazione:** `verified`

## Artefatti

| Livello | File |
|---------|------|
| Dominio | [glossary.md](./glossary.md), [commands-and-events.md](./commands-and-events.md), [conversation-data-plane.md](./conversation-data-plane.md) |
| UML | [messaging-state.puml](../../model/uml/messaging/messaging-state.puml) |
| Statechart | [client/lib/machines/messaging/](../../../client/lib/machines/messaging/) |

## Mapping dominio → implementazione

### Comandi

| Dominio | Statechart (adapter) | Codice |
|---------|----------------------|--------|
| `OpenConversation` | `LoadMessages` | `MessagingCoordinator.init` → `load()` |
| `OpenConversation` | `AttachRealtime` | `MessagingCoordinator.init` → `attachRealtime()` |
| `OpenConversation` | — (side-effect) | `MessagingCoordinator.init` → `effects.markRead()` |
| `SendContent` | `SendStarted` | `MessagesController.send*` → `notifySendStarted()` |
| `RetryFailedSend` | `RetryFailedSend` | `MessagesController.retryMessage` |
| `RefreshConversation` | `RefreshConversation` | `MessagingCoordinator.reload()` |
| `LoadOlderMessages` | — (side-effect in `Ready`) | `MessagingCoordinator.loadOlderMessages()` |
| `CloseConversation` | `DetachRealtime` | `MessagingCoordinator.dispose()` |

### Eventi

| Dominio | Statechart (adapter) | Codice |
|---------|----------------------|--------|
| `ConversationReady` | `ConversationReady` | `ConversationLoadMachine` → `ready` |
| `ConversationUnavailable` | `ConversationUnavailable` | `ConversationLoadMachine` → `sessionBlocked` |
| `ContentSent` | `ContentSent` | `notifySendEnded(false)` |
| `ContentSendFailed` | `ContentSendFailed` | `notifySendEnded(true)` |
| `ConversationUpdated` | `RealtimeReceived` | merge in `ConversationMessageStore` (INSERT messaggi + UPDATE spunte) |

Eventi statechart **solo interni** (non in dominio): `LoadFailed` (errore fetch recuperabile → `ready` con banner), `QueueEmptied`, `FailedQueueRestored`.

### Stati (UML ↔ statechart)

| UML | `ConversationLoadState` / `OutboundSendState` / `RealtimeAttachmentState` |
|-----|---------------------------------------------------------------------------|
| `Loading` | `loading` |
| `Ready` | `ready` |
| `SessionBlocked` | `sessionBlocked` |
| `Idle` | `idle` |
| `Sending` | `sending` |
| `FailedQueue` | `failedQueue` |
| `Detached` | `detached` |
| `Attached` | `attached` |

### Componenti

| Componente | Ruolo |
|------------|-------|
| `MessagingCoordinator` | Compone le tre macchine |
| `MessagesController` | Facade UI |
| `MessagesControllerEffects` | RPC, coda, media, realtime |
| `ConversationMessageStore` | Unica mutazione lista DM |
| `MessageService` | Piattaforma mailbox + realtime |
