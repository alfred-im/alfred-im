# Glossario — contesto notifications

**Bounded context:** `notifications`  
**Ultima revisione:** 2026-07-27  
**Promesse SDD:** [PROM-PUSH-NOTIFY](../../specs/promises/product/PROM-PUSH-NOTIFY.md), [SURF-NOTIFICATIONS](../../specs/surfaces/SURF-NOTIFICATIONS.md), [SYS-PUSH](../../specs/promises/system/SYS-PUSH.md)

---

## Linguaggio ubiquo

| Termine | Definizione |
|---------|-------------|
| **Device** | Browser/dispositivo fisico identificato in modo persistente sul client. Condiviso tra tutti gli account sullo stesso browser. |
| **Push subscription** | Coppia endpoint + chiavi crittografiche registrata nel service worker per un device. Una subscription per coppia account-device. |
| **PushConversationKey** | Identità canonica di una notifica: `(recipient_user_id, peer_profile_id)` — mai solo peer. |
| **Recipient account** | Account Alfred destinatario del messaggio. Può essere non in focus. |
| **Peer** | Controparte nella chat. |
| **Logical message id** | Id messaggio logico per tag notifica e deduplica sul device. |
| **Notification tag** | Tag browser per deduplica: account destinatario + peer + id logico messaggio. |
| **Soppressione** | Nessuna notifica visibile se app in foreground, account destinatario in focus e chat con quel peer aperta. |
| **Suppression state** | Snapshot in RAM nel service worker: account in focus, peer attivo, visibilità app. |
| **Open chat intent** | Intent client con account destinatario e peer da tap notifica o pending. |
| **Pending open chat** | Intent persistito localmente finché sessione non pronta. |
| **Push launch fragment** | URL fragment per cold start da tap notifica verso chat target. |

---

## Confini con altri contesti

| Contesto | Relazione |
|----------|-----------|
| **multi-account** | Manifest account aperti; sync subscription per ogni account. |
| **navigation** | Tap notifica → comando `OpenFromPushTap` (adapter verso `NavigationMachine`). |
| **messaging** | Server invia push solo post-recapito; anteprima come inbox. |
| **delivery** / **reception** | Push solo se messaggio recapitato e allow list superata (server). |

---

## Invarianti

Vedi [invariants.md](invariants.md).
