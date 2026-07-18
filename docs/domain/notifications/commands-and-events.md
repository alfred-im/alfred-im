# Comandi ed eventi — contesto notifications

**Ultima revisione:** 2026-07-18  
**Diagrammi:** [docs/model/uml/notifications/](../../model/uml/notifications/)

---

## Comandi (intento)

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `CheckPushSupport` | App bootstrap | Verifica `PushManager` + `serviceWorker`. |
| `SyncSubscriptions` | `sessionReady`, login, add account, resume app | Registra/aggiorna subscription per tutti gli account nel manifest. |
| `UnregisterSubscription` | Chiudi account | DELETE server + `unsubscribe` locale se ultimo account. |
| `UpdateSuppressionState` | `PushSuppressionBinder` | Invia focus + peer attivo + visibilità app al SW. |
| `HandlePushPayload` | Service worker (`push`) | Valuta soppressione; mostra `Notification` o ignora. |
| `OpenFromPushTap` | Service worker (`notificationclick`) | Focus finestra + `open_chat` verso client (→ navigation). |
| `EnqueueOpenChat` | `PushNotificationListener` | Accoda intent tap; serializza handler. |
| `DrainPendingOpenChat` | `sessionReady`, `hashchange` | Consuma pending / fragment launch. |

---

## Eventi di dominio (cosa è successo)

| Evento | Dopo | Descrizione |
|--------|------|-------------|
| `PushUnsupported` | `CheckPushSupport` | Ambiente senza Web Push. |
| `PermissionDenied` | subscribe / permesso browser | `Notification.permission === denied`. |
| `SubscriptionRegistered` | `SyncSubscriptions` ok | Chiavi VAPID + UPSERT `push_subscriptions`. |
| `SubscriptionSyncFailed` | errore rete/SW | Subscription locale o server non aggiornata. |
| `SuppressionStateApplied` | SW riceve `alfred_push_suppression` | RAM SW aggiornata. |
| `PushNotificationSuppressed` | `HandlePushPayload` + soppressione attiva | Nessuna notifica visibile. |
| `PushNotificationShown` | `showNotification` | Notifica visibile con titolo/anteprima. |
| `OpenChatIntentReceived` | SW `postMessage` o pending drain | Client ha `PushOpenChatIntent` valido. |
| `OpenChatDeferred` | `sessionNotReady` | Intent in `alfred_pending_open_chat`. |
| `OpenChatForwarded` | handler ok | Comando delegato a navigation (`OpenFromPushTap`). |
| `OpenChatRejected` | account non aperto / peer non in inbox | Intent scartato. |

---

## Policy

| Policy | Trigger | Azione |
|--------|---------|--------|
| **Sopprimi in chat attiva** | `PushNotificationReceived` + `shouldSuppress` | `PushNotificationSuppressed` |
| **Persisti se sessione non pronta** | `OpenChatIntentReceived` + `!sessionReady` | `OpenChatDeferred` |
| **Serializza tap** | Più `OpenChatIntentReceived` rapidi | Coda `_openChatChain` |
| **No push su denied** | `permission === denied` | Skip `SyncSubscriptions` |
| **Re-sync on resume** | `AppLifecycleState.resumed` | `SyncSubscriptions` |

---

## Sistemi esterni

| Sistema | Ruolo |
|---------|--------|
| **Browser Push API** | `pushManager.subscribe`, `Notification.permission` |
| **Service worker** (`push_sw.js`) | `push`, `notificationclick`, soppressione RAM |
| **Supabase** | `push_subscriptions`, Edge Function `send-push` |
| **Delivery worker** | Evento `push_notify` post-recapito |

---

## Tracciabilità SDD (riferimento, non duplicazione)

| Elemento modello | Promessa |
|------------------|----------|
| `PushConversationKey` | PROM-PUSH-NOTIFY-033–035 |
| `SyncSubscriptions` | PROM-PUSH-NOTIFY-001–004, SURF-NOTIFICATIONS-001–004 |
| Soppressione | PROM-PUSH-NOTIFY-022–024, SURF-NOTIFICATIONS-008 |
| `OpenFromPushTap` | PROM-PUSH-NOTIFY-030, SURF-NOTIFICATIONS-006–007 |
| Server `push_notify` | SYS-PUSH-020–026 |
