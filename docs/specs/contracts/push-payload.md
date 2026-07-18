# Contratto push payload — Web Push VAPID

**Ultima revisione**: 2026-07-18  
**Status**: `implemented` su `main`  
**Fonte di verità**: `supabase/functions/send-push/index.ts`, `client/web/push_sw.js`, `client/lib/models/push_conversation_key.dart`

Contratto **wire format** per notifiche Web Push: payload server → browser, messaggi `postMessage` service worker ↔ client, e identità conversazione (`PushConversationKey`).

**Promessa infrastruttura**: [SYS-PUSH](../promises/system/SYS-PUSH.md) (riferimento — non duplicare REQ qui).  
**Dominio**: [docs/domain/notifications/](../../domain/notifications/README.md).  
**Persistenza subscription**: [schema.md](./schema.md) § `push_subscriptions` · invio: [rpc.md](./rpc.md) § `send-push`.

---

## 1. Identità conversazione (`PushConversationKey`)

Ogni notifica, soppressione, tap e tag browser identifica **sempre** la coppia account destinatario + peer — mai solo `peer_profile_id`.

| Campo canonico | Alias snake_case (server / outbox) | Alias camelCase (SW / client) | Tipo | Obbligatorio |
|----------------|-------------------------------------|-------------------------------|------|--------------|
| `ownerUserId` | `recipient_user_id` | `recipientUserId` | `string` (uuid) | **sì** |
| `peerProfileId` | `peer_profile_id` | `peerProfileId` | `string` (uuid) | **sì** |

**Invarianti**

- `ownerUserId !== peerProfileId` — coppia non valida → payload ignorato (nessuna UI, nessun `open_chat`).
- Chiave stringa: `ownerUserId + '|' + peerProfileId` (separatore `|`, allineato a `PushConversationKey.separator` e `PUSH_KEY_SEPARATOR` in `push_sw.js`).
- Tag notifica browser: `owner|peer|logical_message_id` se `logical_message_id` presente; altrimenti `owner|peer`.

Implementazione: `client/lib/models/push_conversation_key.dart`, `tryParsePushConversation` in `client/web/push_sw.js`.

---

## 2. Web Push payload (server → service worker)

Il corpo della notifica Web Push è JSON. L'Edge Function `send-push` accetta **snake_case** e inoltra al browser **camelCase**.

### 2.1 Input Edge Function `send-push` (POST)

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "additionalProperties": false,
  "required": [
    "recipient_user_id",
    "peer_profile_id",
    "peer_display_name",
    "preview_text",
    "logical_message_id"
  ],
  "properties": {
    "recipient_user_id": {
      "type": "string",
      "format": "uuid",
      "description": "Account Alfred destinatario (owner archivio che riceve il messaggio)."
    },
    "recipient_display_name": {
      "type": "string",
      "description": "Display name account destinatario — titolo notifica multi-account."
    },
    "recipient_username": {
      "type": ["string", "null"],
      "description": "Username account destinatario — alternativa nel titolo."
    },
    "peer_profile_id": {
      "type": "string",
      "format": "uuid",
      "description": "Profilo controparte nella chat."
    },
    "peer_display_name": {
      "type": "string",
      "description": "Nome visualizzato del peer — corpo titolo notifica."
    },
    "preview_text": {
      "type": "string",
      "description": "Anteprima messaggio (stessa logica inbox / message_preview_text)."
    },
    "logical_message_id": {
      "type": "string",
      "format": "uuid",
      "description": "Id messaggio logico (λ) — deduplica tag notifica per device."
    },
    "content_type": {
      "type": "string",
      "enum": ["text", "gif", "voice", "location", "image", "video"],
      "default": "text",
      "description": "Tipo contenuto — metadato; non espone body completo."
    }
  }
}
```

**Validazione minima** (`send-push`): `recipient_user_id`, `peer_profile_id`, `logical_message_id` obbligatori; 400 se mancanti.

**Origine**: payload outbox `event_kind = push_notify` da `alfred_delivery.queue_push_after_delivery` (migrazioni `20260714100000`, `20260715210000`).

### 2.2 Payload ricevuto dal service worker (`push` event)

L'Edge Function serializza in camelCase prima di `webpush.sendNotification`:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["recipientUserId", "peerProfileId", "logicalMessageId"],
  "properties": {
    "recipientUserId": { "type": "string", "format": "uuid" },
    "recipientDisplayName": { "type": ["string", "null"] },
    "recipientUsername": { "type": ["string", "null"] },
    "peerProfileId": { "type": "string", "format": "uuid" },
    "peerDisplayName": { "type": "string" },
    "previewText": { "type": "string" },
    "logicalMessageId": { "type": "string", "format": "uuid" },
    "contentType": { "type": "string" }
  }
}
```

Il service worker accetta **entrambe** le convenzioni (camelCase e snake_case) su tutti i campi mappati in `tryParsePushConversation`, `formatNotificationTitle`, `pushNotificationTag`.

| Uso SW | Campi letti | Default |
|--------|-------------|---------|
| Titolo | `peerDisplayName` / `peer_display_name`; opz. `recipientUsername` / `recipient_username` o `recipientDisplayName` / `recipient_display_name` | peer: `'Alfred'` |
| Body | `previewText` / `preview_text` | `'Nuovo messaggio'` |
| Tag | `logicalMessageId` / `logical_message_id` + `PushConversationKey` | vedi §1 |
| `Notification.data` | intero payload parsato | — |

---

## 3. Messaggi `postMessage` (service worker ↔ client)

Canale: `navigator.serviceWorker` `message` (non `window.message`). Payload: stringa JSON.

### 3.1 Client → SW: soppressione (`alfred_push_suppression`)

Inviato da `PushPlatform.updateSuppression` (`push_web.dart`) quando cambiano focus account, peer attivo o lifecycle app (`PushSuppressionBinder`).

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "additionalProperties": false,
  "required": ["type", "appVisible"],
  "properties": {
    "type": { "const": "alfred_push_suppression" },
    "focusUserId": {
      "type": ["string", "null"],
      "format": "uuid",
      "description": "Account in focus (`auth.uid()` corrente); null se nessuno."
    },
    "activePeerProfileId": {
      "type": ["string", "null"],
      "format": "uuid",
      "description": "Peer della chat aperta; null se inbox o app non visible."
    },
    "appVisible": {
      "type": "boolean",
      "description": "true solo se `AppLifecycleState.resumed`."
    }
  }
}
```

**Effetto SW**: aggiorna `suppressionState` in RAM. `shouldSuppress(payload)` è true quando:

- `appVisible === true`
- `focusUserId === recipientUserId` del payload push
- `activePeerProfileId === peerProfileId` del payload push

In caso di soppressione: nessuna `showNotification`, nessun `alfred_push_received`.

### 3.2 SW → client: notifica mostrata (`alfred_push_received`)

Dopo `showNotification`, il SW notifica tutte le finestre controllate:

```json
{
  "type": "alfred_push_received",
  "payload": { }
}
```

`payload` è l'oggetto Web Push parsato (§2.2). Il client Flutter **non** apre la chat su questo messaggio — solo aggiornamento badge/realtime opzionale.

### 3.3 SW → client: tap notifica (`open_chat`)

Su `notificationclick`, se esiste una finestra app:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "additionalProperties": false,
  "required": ["type", "recipientUserId", "peerProfileId"],
  "properties": {
    "type": { "const": "open_chat" },
    "recipientUserId": {
      "type": "string",
      "format": "uuid",
      "description": "Account destinatario (ownerUserId)."
    },
    "peerProfileId": {
      "type": "string",
      "format": "uuid",
      "description": "Peer da aprire."
    }
  }
}
```

**Cold start** (nessuna finestra): SW apre `./#push-chat/{recipientUserId}/{peerProfileId}`; il client persiste pending e consuma al `sessionReady`.

Il client accetta anche snake_case su `recipient_user_id` / `peer_profile_id` (`PushConversationKey.tryFromPayload`).

**Handler**: `PushPlatform._handleIncomingMessage` → `PushNotificationListener` → `OpenFromPushTap` (contesto navigation).

---

## 4. Persistenza client (non-SW)

### 4.1 Pending open chat (`localStorage`)

Chiave: `alfred_pending_open_chat`.

```json
{
  "recipientUserId": "<uuid>",
  "peerProfileId": "<uuid>"
}
```

Scritto se `!sessionReady` o da fragment launch; rimosso dopo `OpenChatForwarded` o drain.

### 4.2 Launch fragment

URL hash riservato alle push (non shareable-link):

```
#push-chat/{recipientUserId}/{peerProfileId}
```

Costante: `PUSH_CHAT_FRAGMENT_PREFIX = 'push-chat/'` (`push_sw.js`, `PushDeepLink.fragmentPrefix`).

---

## 5. Diagrammi UML (sequenza)

| Diagramma | Flusso documentato |
|-----------|-------------------|
| [seq-push-received.puml](../../model/uml/notifications/seq-push-received.puml) | Delivery → Edge → SW → soppressione o notifica |
| [seq-suppression-sync.puml](../../model/uml/notifications/seq-suppression-sync.puml) | Client → `alfred_push_suppression` → RAM SW |
| [seq-notification-click.puml](../../model/uml/notifications/seq-notification-click.puml) | Tap → `open_chat` / cold start fragment |
| [seq-sync-subscriptions.puml](../../model/uml/notifications/seq-sync-subscriptions.puml) | Registrazione VAPID (fuori scope payload messaggio) |

State machine: [notifications-sw-state.puml](../../model/uml/notifications/notifications-sw-state.puml), [notifications-client-state.puml](../../model/uml/notifications/notifications-client-state.puml).

---

## 6. Riferimenti implementativi

| Componente | Percorso |
|------------|----------|
| Service worker | `client/web/push_sw.js` |
| Modello chiave | `client/lib/models/push_conversation_key.dart` |
| Soppressione client | `client/lib/widgets/push_suppression_binder.dart` |
| Tap / open chat | `client/lib/widgets/push_notification_listener.dart` |
| Platform web | `client/lib/utils/push_web.dart` |
| Edge Function | `supabase/functions/send-push/index.ts` |
