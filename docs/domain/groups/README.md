# Contesto: groups

**Stato modellazione:** `verified`

Vedi [bounded-contexts.md](../bounded-contexts.md) e [metodo dominio](../README.md).

## Artefatti

| File | Stato |
|------|-------|
| [glossary.md](./glossary.md) | compilato |
| [commands-and-events.md](./commands-and-events.md) | compilato |
| [UML state](../../model/uml/groups/groups-state.puml) | compilato |
| [seq-broadcast](../../model/uml/groups/seq-broadcast.puml) | compilato |
| Statechart client | `client/lib/machines/groups/` — `GroupHomeMachine` + `GroupMessagesMachine` |

## Implementazione runtime

| Componente | Ruolo |
|------------|-------|
| `GroupHomeController` | Facade UI home — delega a `GroupHomeCoordinator` |
| `GroupHomeCoordinator` | Macchina home + effetti (`MessageService`, `ProfileService`) |
| `GroupMessagesController` | Facade UI conversazione — delega a `GroupMessagesCoordinator` |
| `GroupMessagesCoordinator` | Macchina messaggi + broadcast + realtime |
| `GroupHomePanel` | Shell home senza inbox |
| `GroupConversationScreen` | Chat gruppo con `showAuthorLabels` |
| `MessageService` | `fetchOwnerMessages`, `broadcast*ToAllowlist`, `subscribeToOwnerMessages` |
| `home_screen.dart` | Branch `_GroupAccountLayout` se `profile.isGroup` |

## Flussi backend

- Umano → gruppo: `send_message_to_profile` → worker `deliver_internal` → storico gruppo + erogazione
- Gruppo broadcast: `broadcast_message_to_allowlist` → `group_erogate` → `erogate_group_message`

## SDD (confine prodotto)

[SYS-GROUP](../../specs/promises/system/SYS-GROUP.md) · [SYS-DELIVERY](../../specs/promises/system/SYS-DELIVERY.md) · guida [groups.md](../../guides/groups.md)

## Contesti correlati

- **messaging** — chat umano verso gruppo (`peerIsGroup`)
- **delivery** — worker erogazione
- **reception** — gate allow list bidirezionale
- **navigation** — `OpenGroupChat` / `BackToGroupHome`
