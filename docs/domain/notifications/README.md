# Contesto: notifications

**Stato modellazione:** `verified`

## Mapping dominio → implementazione

| Dominio | Statechart / SW | Codice |
|---------|-----------------|--------|
| `RegisterDeviceForPush` | `SyncSubscriptionsRequested` | `PushSubscriptionService` |
| `UnregisterDeviceFromPush` | `UnregisterSubscriptionRequested` | cleanup account |
| `UpdateInChatSuppression` | `UpdateSuppressionState` | `PushSuppressionBinder` → SW |
| `PresentPushNotification` | `HandlePushPayload` | service worker |
| `OpenChatFromNotification` | `OpenChatFromNotification` → `OpenFromPushTap` (navigation) | `NotificationsMachine` |

Statechart: `client/lib/machines/notifications/`
