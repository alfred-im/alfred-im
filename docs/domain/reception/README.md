# Contesto: reception

**Stato modellazione:** `verified`

## Mapping dominio → implementazione

| Dominio | Statechart / server | Codice |
|---------|---------------------|--------|
| `AllowSender` | `AddAllowedProfile` | `ReceptionAllowlistService` |
| `DisallowSender` | `RemoveAllowedPerson` / `RemoveAllowedByProfileId` | `ReceptionAllowlistService` |
| `SearchCandidateSenders` | ricerca coordinator (`searchProfiles`, non evento macchina) | allow list UI |
| `AllowListReady` | `AllowlistLoaded` | `ReceptionMachine` |
| `EvaluateInboundDelivery` | `DeliverInternal` → gate | `is_sender_allowed_for_reception` in worker |
| `EvaluateOutboundSend` | `send_message_to_profile` → gate outbound | `is_sender_allowed_for_reception(sender, recipient)` in RPC |
| `DeliveryPermitted` | `DeliveryPermitted` | INSERT copia destinatario |
| `DeliverySilentlyBlocked` | `DeliverySilentlyBlocked` | outbox `completed`, nessuna copia destinatario |
| `OutboundSendDenied` | eccezione RPC | nessuna copia mittente |

Statechart: `client/lib/machines/reception/` · `ReceptionCoordinator`
