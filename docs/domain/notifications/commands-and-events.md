# Comandi ed eventi — contesto notifications

**Ultima revisione:** 2026-07-27  
**UML:** [docs/model/uml/notifications/](../../model/uml/notifications/)

---

## Comandi dominio

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `RegisterDeviceForPush` | Policy | Registra il device per tutti gli account aperti. |
| `UnregisterDeviceFromPush` | Policy | Rimuove registrazione push del device. |
| `UpdateInChatSuppression` | Policy | Comunica al service worker se sopprimere notifiche. |
| `PresentPushNotification` | Service worker | Valuta e mostra o sopprime una push ricevuta. |
| `OpenChatFromNotification` | Utente (tap) | Apre la chat indicata dalla notifica. |

---

## Eventi dominio

| Evento | Descrizione |
|--------|-------------|
| `PushRegistrationSucceeded` | Device registrato per push. |
| `PushRegistrationSkipped` | Browser non supporta push o permesso negato (sync non avviato). |
| `PushRegistrationFailed` | Sync subscription fallita (errore rete/API). |
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
| `SyncSubscriptionsRequested` | `RegisterDeviceForPush` | |
| `UnregisterSubscriptionRequested` | `UnregisterDeviceFromPush` | |
| `OpenChatFromNotification` | `OpenChatFromNotification` | Stesso nome; include `sessionReady`, `hasOpenAccount`. |
| `PushRegistrationSucceeded` | `PushRegistrationSucceeded` | |
| `PushRegistrationFailed` | `PushRegistrationFailed` | |
| `PushUnsupportedDetected` | *(ingresso)* | Esito `CheckPushSupport`. |
| `PermissionDeniedDetected` | *(ingresso)* | Esito `CheckPushSupport`. |
| `SubscriptionIdleReached` | *(ingresso)* | Supporto ok, permesso non negato. |
| `SessionBecameReady` | *(ingresso)* | Drena solo coda in-memory durante processing serializzato. |

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

## Policy

| Policy | Descrizione |
|--------|-------------|
| **Chiave conversazione** | Ogni notifica identifica account destinatario **e** peer. |
| **Soppressione in chat** | Nessuna notifica se quella chat è già aperta in foreground. |
| **Tap serializzato** | Tap multipli non lasciano chat su peer sbagliato. |

---

## Sistemi esterni

| Sistema | Ruolo |
|---------|------|
| **Browser Push** | Permesso, subscription, visualizzazione. |
| **Service worker** | Ricezione push e tap. |
| **Piattaforma** | Registro subscription e invio push server. |
