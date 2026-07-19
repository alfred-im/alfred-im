# Comandi ed eventi — contesto notifications

**Ultima revisione:** 2026-07-19  
**Diagrammi:** [docs/model/uml/notifications/](../../model/uml/notifications/)

---

## Comandi (intento)

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `CheckPushSupport` | Policy (bootstrap app) | Verifica supporto Web Push nel browser. |
| `SyncSubscriptions` | Policy (sessione pronta, login, resume) | Registra/aggiorna subscription per tutti gli account nel manifest. |
| `UnregisterSubscription` | Policy (chiusura account) | Rimuove subscription server e locale se ultimo account. |
| `UpdateSuppressionState` | Policy (focus/visibilità chat) | Invia stato soppressione al service worker. |
| `HandlePushPayload` | Service worker (`push`) | Valuta soppressione; mostra notifica o ignora. |
| `OpenFromPushTap` | Service worker (`notificationclick`) | Focus finestra + intent chat verso client (→ navigation). |
| `EnqueueOpenChat` | Policy (intent tap ricevuto) | Accoda intent apertura chat; serializza handler. |
| `DrainPendingOpenChat` | Policy (sessione pronta, hashchange) | Consuma intent pending o fragment launch. |

---

## Eventi di dominio

| Evento | Dopo | Descrizione |
|--------|------|-------------|
| `PushUnsupported` | `CheckPushSupport` | Ambiente senza Web Push. |
| `PermissionDenied` | subscribe / permesso browser | Permesso notifiche negato. |
| `SubscriptionRegistered` | `SyncSubscriptions` ok | Subscription registrata per device e account. |
| `SubscriptionSyncFailed` | errore rete/SW | Subscription locale o server non aggiornata. |
| `SuppressionStateApplied` | SW riceve stato soppressione | RAM service worker aggiornata. |
| `PushNotificationSuppressed` | `HandlePushPayload` + soppressione attiva | Nessuna notifica visibile. |
| `PushNotificationShown` | notifica mostrata | Notifica visibile con titolo/anteprima. |
| `OpenChatIntentReceived` | SW postMessage o pending drain | Client ha intent chat valido. |
| `OpenChatDeferred` | sessione non pronta | Intent persistito fino a `sessionReady`. |
| `OpenChatForwarded` | handler ok | Comando delegato a navigation (`OpenFromPushTap`). |
| `OpenChatRejected` | account non aperto / peer irrisolvibile | Intent scartato; nessuna chat stale su altro peer. |

---

## Policy

| Policy | Trigger | Azione |
|--------|---------|--------|
| **Sopprimi in chat attiva** | Push ricevuta + soppressione attiva | `PushNotificationSuppressed` |
| **Persisti se sessione non pronta** | `OpenChatIntentReceived` + sessione non pronta | `OpenChatDeferred` |
| **Serializza tap** | Più intent rapidi | Coda handler |
| **No push su denied** | permesso negato | Skip `SyncSubscriptions` |
| **Re-sync on resume** | App torna in foreground | `SyncSubscriptions` |

---

## Sistemi esterni

| Sistema | Ruolo |
|---------|------|
| **Browser Push API** | Subscription, permesso, visualizzazione notifica |
| **Service worker** | Ricezione push, click, soppressione RAM |
| **Supabase** | Registro subscription, Edge Function invio push |
| **Delivery worker** | Evento push post-recapito riuscito |

---

## Tracciabilità SDD

| Elemento modello | Promessa |
|------------------|----------|
| `PushConversationKey` | PROM-PUSH-NOTIFY-033–035 |
| `SyncSubscriptions` | PROM-PUSH-NOTIFY-001–004, SURF-NOTIFICATIONS-001–004 |
| Soppressione | PROM-PUSH-NOTIFY-022–024, SURF-NOTIFICATIONS-008 |
| `OpenFromPushTap` | PROM-PUSH-NOTIFY-030, SURF-NOTIFICATIONS-006–007 |
| Server push | SYS-PUSH-020–026 |
