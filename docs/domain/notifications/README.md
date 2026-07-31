# Contesto: notifications

**Stato modellazione:** `verified`

**Invarianti:** [invariants.md](invariants.md)

## Mapping dominio → implementazione

### Comandi dominio → eventi statechart client

| Comando dominio | Evento `NotificationsMachine` | Codice |
|-----------------|-------------------------------|--------|
| `RegisterDeviceForPush { scope, reason }` | `SyncSubscriptionsRequested` | `PushCoordinator.syncPushSubscriptions` — scope esplicito; vedi [commands-and-events.md](commands-and-events.md) § Policy sync |
| `UnregisterDeviceFromPush` | `UnregisterSubscriptionRequested` | `PushCoordinator.unregisterAccount` |
| `OpenChatFromNotification` | `OpenChatFromNotification` | `NotificationsAdapters.onOpenChatFromNotification` ← SW / `PushPlatform` |

### Comandi service worker (non passano dalla macchina client)

| Comando dominio | Handler SW | Codice |
|-----------------|------------|--------|
| `UpdateInChatSuppression` | `applySuppressionState` | `PushSuppressionBinder` → `PushPlatform.updateSuppression` |
| `PresentPushNotification` | `HandlePushPayload` | `client/web/push_sw.js` (`push` event) |

### Eventi dominio → statechart client

| Evento dominio | Evento `NotificationsMachine` | Codice |
|----------------|-------------------------------|--------|
| `PushRegistrationSucceeded` | `PushRegistrationSucceeded` | `PushCoordinator` dopo `PushSubscriptionService.syncOpenAccounts` |
| `PushRegistrationSkipped` | *(nessun sync)* | `PushCoordinator` esce prima di `SyncSubscriptionsRequested` se unsupported/denied |
| `PushRegistrationFailed` | `PushRegistrationFailed` | `PushCoordinator` catch su sync |
| `ChatOpenFromNotificationDeferred` | stato `OpenChatQueued` + `persistPendingOpenChat` | `!sessionReady` |
| `ChatOpenFromNotificationFailed` | ritorno `OpenChatIdle` + `clearPendingOpenChat` | `!hasOpenAccount` |
| `ChatOpenFromNotificationSucceeded` | ritorno `OpenChatIdle` dopo `forwardOpenFromPushTap` | effetto → `openFromPushTap` |

### Eventi ingresso (statechart, non comandi dominio)

| Evento statechart | Scopo |
|-------------------|-------|
| `PushUnsupportedDetected` | `CheckPushSupport` → stato `PushUnsupported` |
| `PermissionDeniedDetected` | `CheckPushSupport` → stato `PermissionDenied` |
| `SubscriptionIdleReached` | `CheckPushSupport` ok → stato `Idle` |
| `SessionBecameReady` | Bootstrap sessione → `RegisterDeviceForPush(AllOpenAccounts)`; drena coda in-memory (`_pendingWhileBusy`) |
| `PermissionGrantedDetected` | Permesso → `granted` → `RegisterDeviceForPush(AllOpenAccounts)` |
| `FocusChangedDetected` | Dopo `setFocus` → `RegisterDeviceForPush(FocusedAccount)` |
| `PushSyncDeferred` | Upload/picker attivo — sync rimandato |

### Eventi service worker (non passano dalla macchina client)

| Evento dominio | Handler SW | Codice |
|----------------|------------|--------|
| `NotificationShown` | `showNotification` | `push_sw.js` |
| `NotificationSuppressed` | `shouldSuppress` → skip | `push_sw.js` |

### Stati subscription (UML ↔ `NotificationsSubscriptionState`)

| UML | `NotificationsSubscriptionState` |
|-----|----------------------------------|
| `PushUnsupported` | `pushUnsupported` |
| `PermissionDenied` | `permissionDenied` |
| `Idle` | `idle` |
| `Syncing` | `syncing` |
| `Active` | `active` |

### Stati open chat (UML ↔ `NotificationsOpenChatState`)

| UML | `NotificationsOpenChatState` |
|-----|------------------------------|
| `OpenChatIdle` | `idle` |
| `OpenChatQueued` | `queued` |
| `OpenChatProcessing` | `processing` |

### Adapter verso navigation

Tap notifica: SW `postMessage(open_chat)` → `PushPlatform` → `PushNotificationListener` → `NotificationsMachine` → effetto `forwardOpenFromPushTap` → `openFromPushTap` → `OpenConversation(source=push)`.

**Pending persistito:** `PushPlatform.tryDrainPendingOpenChat` (da `PushNotificationListener` quando `sessionReady`) ri-emette `OpenChatFromNotification`; non passa da `SessionBecameReady` sulla macchina.

## Decisioni architetturali (non debito)

| Scelta | Motivazione |
|--------|-------------|
| **Due percorsi pending** | Coda in-memory (`SessionBecameReady` su macchina) per tap durante `OpenChatProcessing`; `localStorage` per tap a app chiusa — unificare richiederebbe effetti macchina su storage |
| **Soppressione fuori macchina** | `UpdateInChatSuppression` via `PushSuppressionBinder` → SW; la macchina gestisce solo subscription e open-chat |
| **Sync scope esplicito** | Resume PWA = `FocusedAccount` only; grant permesso = `AllOpenAccounts`; push non fa restore sessione focus ([invariants.md](invariants.md) § Sync push) |
| **UML SW descrittivo** | `push_sw.js` è imperativo; diagramma SW documenta policy, non genera codice |
| **`RegisterDeviceForPush` vs `SyncSubscriptionsRequested`** | Comando dominio (policy) vs evento statechart (operazione tecnica) — mapping in tabella sopra |

Statechart: `client/lib/machines/notifications/` · SW: `client/web/push_sw.js`
