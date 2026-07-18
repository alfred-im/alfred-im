# Contesto: contacts

**Stato modellazione:** `verified`

Vedi [glossary.md](./glossary.md) · [commands-and-events.md](./commands-and-events.md) · [UML](../../model/uml/contacts/)

Statechart: `client/lib/machines/contacts/` — produzione via [ContactsCoordinator](../../../client/lib/coordinators/contacts_coordinator.dart) + [ContactsController](../../../client/lib/providers/contacts_controller.dart).

## Artefatti

| File | Stato |
|------|-------|
| [glossary.md](./glossary.md) | compilato |
| [commands-and-events.md](./commands-and-events.md) | compilato |
| [contacts-state.puml](../../model/uml/contacts/contacts-state.puml) | compilato |
| [seq-add-internal-contact.puml](../../model/uml/contacts/seq-add-internal-contact.puml) | compilato |
| [seq-compose-from-contact.puml](../../model/uml/contacts/seq-compose-from-contact.puml) | compilato |
| [statechart](../../../client/lib/machines/contacts/) | `verified` — `ContactsCoordinator` + `ContactsController` |

## Implementazione runtime

| Componente | Ruolo |
|------------|-------|
| `ContactsController` | Facade UI — delega a `ContactsCoordinator` |
| `ContactsCoordinator` | Macchina + effetti servizio (`ContactService`) |
| `ContactService` | PostgREST `contacts` + RPC `search_profiles` |
| `ContactsScreen` | Lista, ricerca, sheet aggiunta Alfred/Esterno |
| `ComposeService.peerFromContact` | Scorciatoia internal → `ChatPeer` |

## SDD (confine prodotto)

[PROM-PERSONAL-CONTACTS](../../specs/promises/product/PROM-PERSONAL-CONTACTS.md) · [SYS-CONTACTS](../../specs/promises/system/SYS-CONTACTS.md) · [SURF-CONTACTS](../../specs/surfaces/SURF-CONTACTS.md)
