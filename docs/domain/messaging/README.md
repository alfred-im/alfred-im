# Contesto: messaging

**Stato modellazione:** `verified`

## Artefatti

| Livello | File |
|---------|------|
| Dominio | [glossary.md](./glossary.md), [commands-and-events.md](./commands-and-events.md), [conversation-data-plane.md](./conversation-data-plane.md) |
| UML | [messaging-state.puml](../../model/uml/messaging/messaging-state.puml), [seq-message-actions-reaction.puml](../../model/uml/messaging/seq-message-actions-reaction.puml), [seq-reaction-fact.puml](../../model/uml/messaging/seq-reaction-fact.puml) |
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
| `OpenMessageActions` | `OpenMessageActions` | tap bolla → `MessageActionsMachine` |
| `CloseMessageActions` | `CloseMessageActions` | dismiss menu |
| `ApplyReaction` | `ApplyReaction` | `PeerMessageService.applyReaction` |
| `WithdrawReaction` | `WithdrawReaction` | `PeerMessageService.withdrawReaction` |

### Eventi

| Dominio | Statechart (adapter) | Codice |
|---------|----------------------|--------|
| `ConversationReady` | `ConversationReady` | `ConversationLoadMachine` → `ready` |
| `ConversationUnavailable` | `ConversationUnavailable` | `ConversationLoadMachine` → `sessionBlocked` |
| `ContentSent` | `ContentSent` | `notifySendEnded(false)` |
| `ContentSendFailed` | `ContentSendFailed` | `notifySendEnded(true)` |
| `ConversationUpdated` | `RealtimeReceived` | merge in `ConversationMessageStore` (INSERT messaggi + fatti reaction + UPDATE spunte) |
| `MessageActionsOpened` | `MessageActionsOpened` | `MessagesController.openMessageActions` |
| `MessageActionsClosed` | `MessageActionsClosed` | `MessagesController.closeMessageActions` |
| `ReactionApplied` | `ReactionApplied` | `MessagingCoordinator.applyReaction` |
| `ReactionWithdrawn` | `ReactionWithdrawn` | `MessagingCoordinator.withdrawReaction` |

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
| `Closed` (MessageActions) | `closed` |
| `Open` (MessageActions) | `open` |

### Componenti

| Componente | Ruolo |
|------------|-------|
| `MessagingCoordinator` | Compone le tre macchine |
| `MessagesController` | Facade UI |
| `MessagesControllerEffects` | RPC, coda, media, realtime |
| `ConversationMessageStore` | Unica mutazione lista DM |
| `PeerMessageService` | Piattaforma mailbox peer + realtime 1:1 |
| `GroupArchiveService` | Archivio owner gruppo + broadcast allowlist |
