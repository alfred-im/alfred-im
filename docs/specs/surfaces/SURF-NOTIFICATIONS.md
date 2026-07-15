# SURF-NOTIFICATIONS — Web Push e service worker

| Campo | Valore |
|-------|--------|
| **Superficie ID** | `SURF-NOTIFICATIONS` |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-15 |
| **Promesse** | [PROM-PUSH-NOTIFY](../promises/product/PROM-PUSH-NOTIFY.md), [SYS-PUSH](../promises/system/SYS-PUSH.md) |

Binding UX e service worker per notifiche Web Push VAPID: permesso browser, registrazione subscription, visualizzazione notifica, tap → chat.

---

## 1. Superficie

| Elemento | Valore |
|----------|--------|
| Service worker | `client/web/push_sw.js` (o modulo registrato da `flutter_bootstrap.js`) |
| Client Dart | `PushSubscriptionService`, `PushSuppressionBinder` |
| Bootstrap | `AppShell` / `AccountManager` — permesso e sync post-login |
| Storage locale | `alfred_device_id` (localStorage), subscription keys via SW |

---

## 2. Promesse SURFACE

### MUST

| ID | Promessa |
|----|----------|
| **SURF-NOTIFICATIONS-001** | Dopo `sessionReady`: se push supportata e permesso ≠ `denied`, registra service worker e `pushManager.subscribe` (VAPID, `userVisibleOnly: true`); con permesso `default` il dialog di sistema compare durante subscribe — **nessuna** `Notification.requestPermission()` separata prima di subscribe |
| **SURF-NOTIFICATIONS-002** | Se `granted`: registra service worker push, `pushManager.subscribe` con VAPID public key, UPSERT `push_subscriptions` per ogni account nel manifest |
| **SURF-NOTIFICATIONS-003** | Post-login / «Aggiungi account»: re-registrazione subscription per il nuovo `user_id` |
| **SURF-NOTIFICATIONS-004** | «Chiudi account»: DELETE subscription server + `unsubscribe` locale se ultimo account sul device |
| **SURF-NOTIFICATIONS-005** | Handler SW `push`: mostra `Notification` con titolo e anteprima ([PROM-PUSH-NOTIFY](../promises/product/PROM-PUSH-NOTIFY.md) PROM-PUSH-NOTIFY-010) |
| **SURF-NOTIFICATIONS-006** | Handler SW `notificationclick`: focus finestra app + messaggio client `{ type: 'open_chat', recipientUserId, peerProfileId }` — **entrambi** obbligatori |
| **SURF-NOTIFICATIONS-007** | Client riceve `open_chat` → parse [`PushConversationKey`](../../client/lib/models/push_conversation_key.dart) → focus `recipientUserId` + apre chat `peerProfileId` |
| **SURF-NOTIFICATIONS-008** | Soppressione: SW consulta stato client (focus + peer attivo) e confronta la **coppia** account+peer del payload prima di `showNotification` |
| **SURF-NOTIFICATIONS-009** | Icona notifica: `icons/Icon-192.png`; `badge` coerente brand `#2D2926` |
| **SURF-NOTIFICATIONS-010** | Payload push incompleto (manca `recipientUserId` o `peerProfileId`) → nessuna notifica visibile e nessun `open_chat` |

### SHOULD

| ID | Promessa |
|----|----------|
| **SURF-NOTIFICATIONS-020** | `last_seen_at` aggiornato su ogni re-registrazione subscription |
| **SURF-NOTIFICATIONS-021** | Tag notifica = `recipient_user_id|peer_profile_id|logical_message_id` ([PROM-PUSH-NOTIFY](../promises/product/PROM-PUSH-NOTIFY.md) PROM-PUSH-NOTIFY-035) |

### MUST NOT

| ID | Promessa |
|----|----------|
| **SURF-NOTIFICATIONS-030** | Richiedere permesso ripetutamente dopo `denied` |
| **SURF-NOTIFICATIONS-031** | Mostrare notifica senza controllare soppressione |
| **SURF-NOTIFICATIONS-032** | Service worker che bypassa RLS o invia push autonomamente |

### Note piattaforma

| ID | Nota |
|----|------|
| **SURF-NOTIFICATIONS-040** | iOS: push web solo PWA installata (Add to Home Screen), iOS ≥ 16.4 — non garantito in Safari tab |
| **SURF-NOTIFICATIONS-041** | GitHub Pages HTTPS: requisito Web Push soddisfatto |

---

## 3. Tracciabilità

| SURF-ID / PROM-ID | Verifica |
|-------------------|----------|
| SURF-NOTIFICATIONS-001–002 | `client/test/unit/notification_permission_test.dart`; `client/e2e/push-registration.spec.ts` |
| SURF-NOTIFICATIONS-003–004 | `client/test/unit/push_subscription_service_test.dart` |
| SURF-NOTIFICATIONS-005–008 | `client/test/unit/push_suppression_test.dart`; `client/test/unit/push_conversation_key_test.dart`; `client/e2e/push-full.spec.ts` |
| SURF-NOTIFICATIONS-006–007 | `client/test/widget/push_notification_listener_test.dart`; `client/e2e/push-full.spec.ts` |
| SURF-NOTIFICATIONS-008 | `client/test/unit/push_suppression_test.dart` |
| PROM-PUSH-NOTIFY-022 | Scenario manuale in [PROM-PUSH-NOTIFY](../promises/product/PROM-PUSH-NOTIFY.md) §6 |

**Gate**: `bash scripts/check-spec-sync.sh` + `verify.sh` + `bash scripts/test.sh e2e-push-local` (stack locale)

---

## 4. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [PROM-PUSH-NOTIFY](../promises/product/PROM-PUSH-NOTIFY.md) | Regole prodotto |
| [SYS-PUSH](../promises/system/SYS-PUSH.md) | Server e VAPID |
| [SURF-APP-SHELL](./SURF-AUTH.md) | Shell sempre visibile |
| [registry.md](../registry.md) | Indice promesse |
