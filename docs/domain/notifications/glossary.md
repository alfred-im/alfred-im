# Glossario — contesto notifications

**Bounded context:** `notifications`  
**Ultima revisione:** 2026-07-18  
**Promesse SDD:** [PROM-PUSH-NOTIFY](../../specs/promises/product/PROM-PUSH-NOTIFY.md), [SURF-NOTIFICATIONS](../../specs/surfaces/SURF-NOTIFICATIONS.md), [SYS-PUSH](../../specs/promises/system/SYS-PUSH.md)

---

## Linguaggio ubiquo

| Termine | Definizione |
|---------|-------------|
| **Device** | Browser/dispositivo fisico identificato da `device_id` (`alfred_device_id` in `localStorage`). Condiviso tra tutti gli account sullo stesso browser. |
| **Push subscription** | Coppia endpoint + chiavi VAPID (`p256dh`, `auth`) registrata nel service worker per un device. Una riga `push_subscriptions` per `(user_id, device_id)`. |
| **PushConversationKey** | Identità canonica di una notifica: `(recipient_user_id, peer_profile_id)` — mai solo peer. Formato stringa: `owner\|peer`. |
| **Recipient account** | Account Alfred destinatario del messaggio (`recipient_user_id` nel payload). Può essere non in focus. |
| **Peer** | Controparte nella chat (`peer_profile_id`). |
| **Logical message id** | Id messaggio logico per tag notifica e deduplica sul device. |
| **Notification tag** | Tag browser: `recipient_user_id\|peer_profile_id\|logical_message_id`. |
| **Soppressione** | Nessuna notifica visibile se app in foreground, account destinatario in focus e chat con quel peer aperta. |
| **Suppression state** | Snapshot in RAM nel service worker: `focusUserId`, `activePeerProfileId`, `appVisible`. |
| **Open chat intent** | Intent client `{ type: open_chat, recipientUserId, peerProfileId }` da tap notifica o pending. |
| **Pending open chat** | Intent persistito in `localStorage` (`alfred_pending_open_chat`) finché `sessionReady`. |
| **Push launch fragment** | URL `#push-chat/{owner}/{peer}` per cold start da tap notifica. |

---

## Confini con altri contesti

| Contesto | Relazione |
|----------|-----------|
| **multi-account** | Manifest account aperti; sync subscription per ogni `user_id`. |
| **navigation** | Tap notifica → comando `OpenFromPushTap` (adapter verso `NavigationMachine`). |
| **messaging** | Server invia push solo post-recapito; anteprima come inbox. |
| **delivery** / **reception** | Push solo se messaggio recapitato e allow list superata (server). |

---

## Invarianti

1. **Mai solo peer:** target, soppressione, tap e tag usano sempre `PushConversationKey` (account + peer).
2. **Payload incompleto:** senza `recipient_user_id` e `peer_profile_id` → nessuna UI, nessun `open_chat`.
3. **Permesso `denied`:** app funziona senza push; nessun retry invasivo.
4. **Subscription per account:** UPSERT solo per `user_id` dell'account; DELETE alla chiusura account sul device.
5. **Soppressione client→SW:** stato sincronizzato via `postMessage` (`alfred_push_suppression`).
