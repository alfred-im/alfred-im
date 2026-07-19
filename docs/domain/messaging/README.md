# Contesto: messaging

**Stato modellazione:** `verified`

## Artefatti

| Livello | File |
|---------|------|
| Dominio | [glossary.md](./glossary.md), [commands-and-events.md](./commands-and-events.md) |
| UML | [messaging-state.puml](../../model/uml/messaging/messaging-state.puml) |
| Statechart | [client/lib/machines/messaging/](../../../client/lib/machines/messaging/) |

## Mapping dominio → implementazione

| Dominio (DDD) | Statechart | Codice |
|---------------|------------|--------|
| `OpenConversation` | `LoadMessages`, `AttachRealtime`, `MarkRead` | `MessagingCoordinator` init ciclo |
| `SendContent` | `SendStarted` → `ContentSent` / `ContentSendFailed` | `SendMessage`, `SendGif`, `SendVoice`, … |
| `RetryFailedSend` | `RetryFailedSend` | `RetryMessage` |
| `RefreshConversation` | `RefreshConversation` | reload su `ConversationLoadMachine` |
| `LoadOlderMessages` | side-effect in `Ready` (no transizione macchina) | `MessagingCoordinator.loadOlderMessages` / `MessageService.fetchPeerMessages(beforeCreatedAt: …)` |
| `ConversationReady` | `ConversationReady` / stato `ready` | lista messaggi in UI |
| `ContentSent` | `ContentSent` | merge riga server |
| `ContentSendFailed` | `ContentSendFailed` | coda `OutboundMessageQueue` |
| `ConversationUpdated` | `RealtimeReceived`, `DeliveryTickReceived` | merge realtime |

| Componente | Ruolo |
|------------|-------|
| `MessagingCoordinator` | Compone le tre macchine |
| `MessagesController` | Facade UI |
| `MessagesControllerEffects` | RPC, coda, media, realtime |
| `MessageService` | Piattaforma mailbox + realtime |
