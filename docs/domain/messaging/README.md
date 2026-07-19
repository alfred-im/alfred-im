# Contesto: messaging

**Stato modellazione:** `verified`

Vedi [bounded-contexts.md](../bounded-contexts.md) e [metodo dominio](../README.md).

## Artefatti

| File | Stato |
|------|-------|
| [glossary.md](./glossary.md) | compilato |
| [commands-and-events.md](./commands-and-events.md) | compilato |
| [UML composite](../../model/uml/messaging/messaging-state.puml) | compilato |
| [conversation-load-state.puml](../../model/uml/messaging/conversation-load-state.puml) | compilato |
| [outbound-send-state.puml](../../model/uml/messaging/outbound-send-state.puml) | compilato |
| [realtime-attachment-state.puml](../../model/uml/messaging/realtime-attachment-state.puml) | compilato |
| [seq-send-optimistic](../../model/uml/messaging/seq-send-optimistic.puml) | compilato |
| [seq-realtime-merge](../../model/uml/messaging/seq-realtime-merge.puml) | compilato |
| [statechart](../../../client/lib/machines/messaging/) | **verified** (3 macchine + coordinator) |

## Implementazione runtime

| Componente | Ruolo |
|------------|-------|
| `MessagesController` | Facade UI — API widget invariata |
| `MessagingCoordinator` | Compone load / outbound / realtime |
| `MessagesControllerEffects` | RPC, coda, media, realtime |
| `MessageService` | RPC + subscribe Realtime owner |
| `OutboundMessageQueue` | Coda persistente e media retry |

### Macchine (`client/lib/machines/messaging/`)

| Macchina | Stati | UML |
|----------|-------|-----|
| `ConversationLoadMachine` | Loading, Ready, SessionBlocked | [conversation-load-state.puml](../../model/uml/messaging/conversation-load-state.puml) |
| `OutboundSendMachine` | Idle, Sending, FailedQueue | [outbound-send-state.puml](../../model/uml/messaging/outbound-send-state.puml) |
| `RealtimeAttachmentMachine` | Detached, Attached | [realtime-attachment-state.puml](../../model/uml/messaging/realtime-attachment-state.puml) |

## SDD (confine prodotto)

[PROM-OUTBOUND-SEND](../../specs/promises/product/PROM-OUTBOUND-SEND.md) · [PROM-MESSAGE-STATUS](../../specs/promises/product/PROM-MESSAGE-STATUS.md) · [PROM-REALTIME-OWNER](../../specs/promises/product/PROM-REALTIME-OWNER.md) · [SYS-MAILBOX](../../specs/promises/system/SYS-MAILBOX.md)

## Sotto-contesto media

Voice, foto, video, location: [docs/domain/media/](../media/)
