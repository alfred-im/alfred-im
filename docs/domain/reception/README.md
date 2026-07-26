# Contesto: reception

**Stato modellazione:** `verified`

## Mapping dominio → implementazione

| Dominio | Statechart / server | Codice |
|---------|---------------------|--------|
| `AllowSender` | `AddAllowedProfile` | `ReceptionAllowlistService` |
| `DisallowSender` | `RemoveAllowedPerson` / `RemoveAllowedByProfileId` | `ReceptionAllowlistService` |
| `SearchCandidateSenders` | `SearchProfiles` (coordinator, non macchina) | allow list UI |
| `AllowListReady` | `AllowlistLoaded` | `ReceptionMachine` |
| `EvaluateInboundDelivery` | `DeliverInternal` → gate | `is_sender_allowed_for_reception` in worker |
| `DeliveryPermitted` | `DeliveryPermitted` | INSERT copia destinatario |
| `DeliverySilentlyBlocked` | `DeliverySilentlyBlocked` | outbox `completed`, nessuna copia destinatario |

Statechart: `client/lib/machines/reception/` · `ReceptionCoordinator`
