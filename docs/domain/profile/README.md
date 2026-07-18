# Contesto: profile

**Stato modellazione:** `verified`

Vedi [glossary.md](./glossary.md) · [commands-and-events.md](./commands-and-events.md) · [UML](../../model/uml/profile/)

Statechart: `client/lib/machines/profile/` — produzione via [ProfileCoordinator](../../../client/lib/coordinators/profile_coordinator.dart) + [ProfileController](../../../client/lib/providers/profile_controller.dart).

## Artefatti

| File | Stato |
|------|-------|
| [glossary.md](./glossary.md) | compilato |
| [commands-and-events.md](./commands-and-events.md) | compilato |
| [profile-edit-state.puml](../../model/uml/profile/profile-edit-state.puml) | compilato |
| [seq-save-own-profile.puml](../../model/uml/profile/seq-save-own-profile.puml) | compilato |
| [seq-peer-profile-overlay.puml](../../model/uml/profile/seq-peer-profile-overlay.puml) | compilato |
| [statechart](../../../client/lib/machines/profile/) | `verified` — `ProfileCoordinator` + `ProfileController` |

## Implementazione runtime

| Componente | Ruolo |
|------------|-------|
| `ProfileSummary` / `UserProfile` | Modelli identità pubblica |
| `ProfileService` | UPDATE profilo, lookup username/id |
| `ProfileAvatarService` | Upload bucket `avatars` |
| `ProfileController` | Facade UI — delega a `ProfileCoordinator` |
| `ProfileCoordinator` | Macchina + effetti servizio (`ProfileService`, `ProfileAvatarService`) |
| `ProfileScreen` | Form edit profilo proprio |
| `profile_identity.dart` | `ProfileAvatar`, `ProfileIdentityLines` |
| `peer_profile_overlay.dart` | Scheda peer + allow/rubrica/chat/share |

## SDD (confine prodotto)

[PROM-PROFILE-IDENTITY](../../specs/promises/product/PROM-PROFILE-IDENTITY.md) · [PROM-PEER-PROFILE](../../specs/promises/product/PROM-PEER-PROFILE.md) · [SYS-PROFILE](../../specs/promises/system/SYS-PROFILE.md) · [SURF-PROFILE](../../specs/surfaces/SURF-PROFILE.md)
