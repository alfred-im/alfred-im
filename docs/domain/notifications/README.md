# Contesto: notifications

**Stato modellazione:** `verified`

**Invarianti:** [invariants.md](invariants.md)

## Mapping dominio → implementazione

| Dominio | Statechart / SW | Codice |
|---------|-----------------|--------|
| `RegisterDeviceForPush` | `SyncSubscriptionsRequested` | `PushSubscriptionService` |
| `UnregisterDeviceFromPush` | `UnregisterSubscriptionRequested` | cleanup account |
| `UpdateInChatSuppression` | `UpdateSuppressionState` | `PushSuppressionBinder` → SW |
| `PresentPushNotification` | `HandlePushPayload` | service worker |
| `OpenChatFromNotification` | `OpenChatFromNotification` → `OpenFromPushTap` (navigation) | `NotificationsMachine` |

Statechart: `client/lib/machines/notifications/`
