# Contesto: messaging

**Stato modellazione:** `verified`

Vedi [bounded-contexts.md](../bounded-contexts.md) e [metodo dominio](../README.md).

## Artefatti

| File | Stato |
|------|-------|
| [glossary.md](./glossary.md) | compilato |
| [commands-and-events.md](./commands-and-events.md) | compilato |
| [UML state](../../model/uml/messaging/messaging-state.puml) | compilato |
| [seq-send-optimistic](../../model/uml/messaging/seq-send-optimistic.puml) | compilato |
| [seq-realtime-merge](../../model/uml/messaging/seq-realtime-merge.puml) | compilato |
| [statechart](../../../client/lib/machines/messaging/) | **verified** (3 macchine + coordinator) |

## Implementazione runtime

| Componente | Ruolo |
|------------|-------|
| `MessagesController` | Thin delegate — API widget invariata |
| `MessagingCoordinator` | Compone load / outbound / realtime |
| `MessagesControllerEffects` | RPC, coda, media, realtime |
| `MessageService` | RPC + subscribe Realtime owner |
| `OutboundMessageQueue` | Coda persistente e media retry |

### Macchine (`client/lib/machines/messaging/`)

| Macchina | Stati |
|----------|-------|
| `ConversationLoadMachine` | Loading, Ready, SessionBlocked |
| `OutboundSendMachine` | Idle, Sending, FailedQueue |
| `RealtimeAttachmentMachine` | Detached, Attached |

## SDD (confine prodotto)

[PROM-OUTBOUND-SEND](../../specs/promises/product/PROM-OUTBOUND-SEND.md) · [PROM-MESSAGE-STATUS](../../specs/promises/product/PROM-MESSAGE-STATUS.md) · [PROM-REALTIME-OWNER](../../specs/promises/product/PROM-REALTIME-OWNER.md) · [SYS-MAILBOX](../../specs/promises/system/SYS-MAILBOX.md)

## Sotto-contesto media

Voice, foto, video, location: [docs/domain/media/](../media/)
