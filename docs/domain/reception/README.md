# Contesto: reception

**Stato modellazione:** `verified`

Vedi [glossary.md](./glossary.md) · [commands-and-events.md](./commands-and-events.md) · [UML](../../model/uml/reception/)

Statechart: `client/lib/machines/reception/` — produzione via [ReceptionCoordinator](../../../client/lib/coordinators/reception_coordinator.dart) + [ReceptionAllowlistController](../../../client/lib/providers/reception_allowlist_controller.dart).

## Artefatti

| File | Stato |
|------|-------|
| [glossary.md](./glossary.md) | compilato |
| [commands-and-events.md](./commands-and-events.md) | compilato |
| [reception-allowlist-state.puml](../../model/uml/reception/reception-allowlist-state.puml) | compilato |
| [seq-add-allowed-profile.puml](../../model/uml/reception/seq-add-allowed-profile.puml) | compilato |
| [seq-reception-delivery-gate.puml](../../model/uml/reception/seq-reception-delivery-gate.puml) | compilato |
| [statechart](../../../client/lib/machines/reception/) | `verified` — `ReceptionCoordinator` + `ReceptionAllowlistController` |

## Implementazione runtime

| Componente | Ruolo |
|------------|-------|
| `ReceptionAllowlistController` | Facade UI — delega a `ReceptionCoordinator` |
| `ReceptionCoordinator` | Macchina + effetti servizio (`ReceptionAllowlistService`) |
| `ReceptionAllowlistService` | PostgREST `reception_allowlist` + `search_profiles` |
| `AllowedPeopleScreen` | Gestione lista «Persone consentite» |
| `PeerProfileOverlay` | Toggle «Consenti messaggi» |
| `alfred_delivery` (server) | Gate recapito prima copia destinatario |

## SDD (confine prodotto)

[SYS-RECEPTION](../../specs/promises/system/SYS-RECEPTION.md) · [PROM-RECEPTION-FILTER](../../specs/promises/product/PROM-RECEPTION-FILTER.md) · [SURF-ALLOWLIST](../../specs/surfaces/SURF-ALLOWLIST.md)
