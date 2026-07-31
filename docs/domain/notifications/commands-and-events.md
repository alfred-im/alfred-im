# Comandi ed eventi — contesto notifications

**Ultima revisione:** 2026-07-28  
**UML:** [docs/model/uml/notifications/](../../model/uml/notifications/)

---

## Comandi dominio

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `RegisterDeviceForPush` | Policy | Registra il device per uno o più account — **scope esplicito** (vedi sotto). |
| `UnregisterDeviceFromPush` | Policy | Rimuove registrazione push del device per un `user_id`. |
| `UpdateInChatSuppression` | Policy | Comunica al service worker se sopprimere notifiche. |
| `PresentPushNotification` | Service worker | Valuta e mostra o sopprime una push ricevuta. |
| `OpenChatFromNotification` | Utente (tap) | Apre la chat indicata dalla notifica. |

### `RegisterDeviceForPush` — parametri

```
RegisterDeviceForPush {
  scope: AllOpenAccounts | FocusedAccount | NewAccount(userId) | Unregister(userId)
  reason: SessionReady | AccountOpened | FocusChanged | PermissionGranted | AppResumed | SubscriptionRotated
}
```

| Scope | Significato |
|-------|-------------|
| `AllOpenAccounts` | UPSERT `push_subscriptions` per ogni account nel manifest con permesso `granted` |
| `FocusedAccount` | UPSERT solo per l'account in focus |
| `NewAccount(userId)` | UPSERT per l'account appena aperto |
| `Unregister(userId)` | DELETE riga per `(user_id, device_id)` |

**Vincolo:** la registrazione push **non** promuove un account a focus e **non** dispose della sessione GoTrue in RAM ([PROM-PUSH-NOTIFY-046](../../specs/promises/product/PROM-PUSH-NOTIFY.md)). Per account non in focus usare client auth effimero o equivalente — non `AccountSession.restore` nel percorso caldo.

---

## Eventi dominio

| Evento | Descrizione |
|--------|-------------|
| `PushRegistrationSucceeded` | Device registrato per push (scope completato). |
| `PushRegistrationSkipped` | Browser non supporta push o permesso negato (sync non avviato). |
| `PushRegistrationFailed` | Sync subscription fallita (errore rete/API). |
| `PushSyncDeferred` | Sync rimandato (upload media / picker attivo). |
| `NotificationPermissionGranted` | Permesso browser passato a `granted`. |
| `FocusChanged` | Focus account completato con successo. |
| `NotificationShown` | Notifica visibile all'utente. |
| `NotificationSuppressed` | Notifica non mostrata (chat attiva). |
| `ChatOpenFromNotificationSucceeded` | Chat aperta da tap notifica. |
| `ChatOpenFromNotificationDeferred` | Tap salvato fino a sessione pronta. |
| `ChatOpenFromNotificationFailed` | Account o peer non risolvibili. |

---

## Eventi statechart client (`NotificationsMachine`)

Mapping completo: [README.md](README.md).

| Evento statechart | Comando / evento dominio | Note |
|-------------------|--------------------------|------|
| `SyncSubscriptionsRequested` | `RegisterDeviceForPush` | Include `scope` e `reason` |
| `UnregisterSubscriptionRequested` | `UnregisterDeviceFromPush` | |
| `OpenChatFromNotification` | `OpenChatFromNotification` | Stesso nome; include `sessionReady`, `hasOpenAccount`. |
| `PushRegistrationSucceeded` | `PushRegistrationSucceeded` | |
| `PushRegistrationFailed` | `PushRegistrationFailed` | |
| `PushSyncDeferred` | `PushSyncDeferred` | Upload/picker attivo |
| `PushUnsupportedDetected` | *(ingresso)* | Esito `CheckPushSupport`. |
| `PermissionDeniedDetected` | *(ingresso)* | Esito `CheckPushSupport`. |
| `PermissionGrantedDetected` | `NotificationPermissionGranted` | → `RegisterDeviceForPush(AllOpenAccounts)` |
| `FocusChangedDetected` | `FocusChanged` | → `RegisterDeviceForPush(FocusedAccount)` |
| `SubscriptionIdleReached` | *(ingresso)* | Supporto ok, permesso non negato. |
| `SessionBecameReady` | *(ingresso)* | → `RegisterDeviceForPush(AllOpenAccounts)`; drena coda open-chat in-memory |

`PushRegistrationSkipped` non è un evento macchina: il coordinator non invia `SyncSubscriptionsRequested`.

---

## Service worker (`push_sw.js`)

| Messaggio / handler | Comando dominio | Evento dominio |
|---------------------|-----------------|----------------|
| `alfred_push_suppression` | `UpdateInChatSuppression` | — |
| `push` → `shouldSuppress` | `PresentPushNotification` | `NotificationSuppressed` |
| `push` → `showNotification` | `PresentPushNotification` | `NotificationShown` |
| `notificationclick` → `open_chat` | — | innesca `OpenChatFromNotification` sul client |

---

## Policy sync (trigger → scope)

Vincolante — [PROM-PUSH-NOTIFY](../../specs/promises/product/PROM-PUSH-NOTIFY.md) § politica sync.

| Trigger | Evento / reason | Scope | MUST NOT |
|---------|-----------------|-------|----------|
| Bootstrap `sessionReady` | `SessionReady` | `AllOpenAccounts` | — |
| Login / aggiungi account | `AccountOpened` | `NewAccount` (min); SHOULD `AllOpenAccounts` | — |
| `removeAccount` | — | `Unregister` | — |
| Cambio focus | `FocusChanged` | `FocusedAccount` | restore altri account |
| Permesso → `granted` | `PermissionGranted` | `AllOpenAccounts` | — |
| Resume PWA | `AppResumed` | `FocusedAccount` | `AllOpenAccounts` |
| Resume + upload/picker attivo | `AppResumed` | **nessun sync** (`PushSyncDeferred`) | qualsiasi restore auth |
| Chiavi device ruotate (SW) | `SubscriptionRotated` | `FocusedAccount` o `AllOpenAccounts` | SHOULD debounce |

### Policy invarianti

| Policy | Descrizione |
|--------|-------------|
| **Chiave conversazione** | Ogni notifica identifica account destinatario **e** peer. |
| **Soppressione in chat** | Nessuna notifica se quella chat è già aperta in foreground. |
| **Tap serializzato** | Tap multipli non lasciano chat su peer sbagliato. |
| **Una GoTrue in RAM** | Sync push non cambia focus né dispose sessione attiva ([PROM-MULTI-ACCOUNT-006](../../specs/promises/product/PROM-MULTI-ACCOUNT.md)). |
| **Percorso caldo media** | Upload allegato e picker OS hanno priorità su sync push ([PROM-CHAT-MEDIA](../../specs/promises/product/PROM-CHAT-MEDIA.md)). |

---

## Sistemi esterni

| Sistema | Ruolo |
|---------|--------|
| **Browser Push** | Permesso, subscription, visualizzazione. |
| **Service worker** | Ricezione push e tap. |
| **Piattaforma** | Registro subscription e invio push server. |
