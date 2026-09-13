# Contratto push payload — Web Push VAPID

**Ultima revisione**: 2026-09-13  
**Status**: `approved` — amend §7.19 `peerAddress` (migrazione dev pendente; codice attuale ancora su `peerProfileId`)  
**Fonte di verità target**: `supabase/functions/send-push/index.ts`, `client/web/push_sw.js`, `client/lib/models/push_conversation_key.dart`

Contratto **wire format** per notifiche Web Push: payload server → browser, messaggi `postMessage` service worker ↔ client, e identità conversazione (`PushConversationKey`).

**Promessa infrastruttura**: [SYS-PUSH](../promises/system/SYS-PUSH.md).  
**Dominio**: [docs/domain/notifications/](../../domain/notifications/README.md).  
**Persistenza subscription**: [schema.md](./schema.md) § `push_subscriptions` · invio: [rpc.md](./rpc.md) § `send-push`.

**Regola §7.19**: payload push e deep link usano **`peerAddress`** (stringa indirizzo lowercase). **Nessun periodo dual-read** — non mantenere lettura parallela di `peerProfileId`.

---

## 1. Identità conversazione (`PushConversationKey`)

Ogni notifica, soppressione, tap e tag browser identifica **sempre** la coppia account destinatario + **indirizzo controparte** — mai UUID profilo.

| Campo canonico | Alias snake_case (server / outbox) | Alias camelCase (SW / client) | Tipo | Obbligatorio |
|----------------|-------------------------------------|-------------------------------|------|--------------|
| `recipientUserId` | `recipient_user_id` | `recipientUserId` | `string` (uuid) | **sì** |
| `peerAddress` | `peer_address` | `peerAddress` | `string` (indirizzo lowercase) | **sì** |

**Rimosso**: `peerProfileId` / `peer_profile_id` — **MUST NOT** apparire in payload nuovi.

**Invarianti**

- `peerAddress` non può essere l'indirizzo del titolare `recipientUserId` — coppia non valida → payload ignorato.
- Chiave stringa: `recipientUserId + '|' + peerAddress` (separatore `|`, allineato a `PushConversationKey.separator` e `PUSH_KEY_SEPARATOR` in `push_sw.js`).
- Tag notifica browser: `recipient|peerAddress|logical_message_id` se `logical_message_id` presente; altrimenti `recipient|peerAddress`.

Implementazione target: `client/lib/models/push_conversation_key.dart`, `tryParsePushConversation` in `client/web/push_sw.js`.

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
    "peer_address",
    "peer_display_name",
    "preview_text",
    "logical_message_id"
  ],
  "properties": {
    "recipient_user_id": {
      "type": "string",
      "format": "uuid",
      "description": "Account Alfred destinatario (titolare archivio che riceve il messaggio)."
    },
    "recipient_display_name": {
      "type": "string",
      "description": "Display name account destinatario — titolo notifica multi-account."
    },
    "recipient_username": {
      "type": ["string", "null"],
      "description": "Username account destinatario — alternativa nel titolo."
    },
    "peer_address": {
      "type": "string",
      "description": "Indirizzo controparte lowercase — chiave conversazione (username o user@server)."
    },
    "peer_display_name": {
      "type": "string",
      "description": "Nome visualizzato del peer — corpo titolo notifica (fallback: peer_address)."
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
      "default": "text"
    },
    "icon_url": {
      "type": ["string", "null"],
      "description": "URL icona notifica — da `instance.branding.logo_url` al momento del queue."
    }
  }
}
```

**Validazione minima** (`send-push`): `recipient_user_id`, `peer_address`, `logical_message_id` obbligatori; 400 se mancanti.

**Origine**: payload outbox `event_kind = push_notify` da `alfred_delivery.queue_push_after_delivery` — campo `peer_address` da riga destinatario materializzata.

### 2.2 Payload ricevuto dal service worker (`push` event)

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["recipientUserId", "peerAddress", "logicalMessageId"],
  "properties": {
    "recipientUserId": { "type": "string", "format": "uuid" },
    "recipientDisplayName": { "type": ["string", "null"] },
    "recipientUsername": { "type": ["string", "null"] },
    "peerAddress": { "type": "string" },
    "peerDisplayName": { "type": "string" },
    "previewText": { "type": "string" },
    "logicalMessageId": { "type": "string", "format": "uuid" },
    "contentType": { "type": "string" },
    "iconUrl": { "type": ["string", "null"] }
  }
}
```

Il service worker accetta camelCase e snake_case sui campi mappati.

| Uso SW | Campi letti | Default |
|--------|-------------|---------|
| Titolo | `peerDisplayName` / `peer_display_name`; fallback `peerAddress` | indirizzo grezzo |
| Body | `previewText` / `preview_text` | `'Nuovo messaggio'` |
| Tag | `logicalMessageId` + `PushConversationKey` | vedi §1 |
| Icon / badge | `iconUrl` / `icon_url` | `'icons/Icon-192.png'` |
| `Notification.data` | intero payload parsato | — |

---

## 3. Messaggi `postMessage` (service worker ↔ client)

Canale: `navigator.serviceWorker` `message` (non `window.message`). Payload: stringa JSON.

### 3.1 Client → SW: soppressione (`alfred_push_suppression`)

```json
{
  "type": "alfred_push_suppression",
  "recipientUserId": "<uuid|null>",
  "activePeerAddress": "<indirizzo|null>",
  "appVisible": true
}
```

**Effetto SW**: `shouldSuppress(payload)` è true quando:

- `appVisible === true`
- `recipientUserId === recipientUserId` del payload push
- `activePeerAddress === peerAddress` del payload push

**Rimosso**: `activePeerProfileId` — sostituito da `activePeerAddress`.

### 3.2 SW → client: notifica mostrata (`alfred_push_received`)

Invariato — `payload` è l'oggetto Web Push parsato (§2.2).

### 3.3 SW → client: tap notifica (`open_chat`)

```json
{
  "type": "open_chat",
  "recipientUserId": "<uuid>",
  "peerAddress": "<indirizzo lowercase>"
}
```

**Cold start** (nessuna finestra): SW apre `./#push-chat/{recipientUserId}/{peerAddress}` (segmento URL-encoded).

Il client accetta anche snake_case su `recipient_user_id` / `peer_address`.

**Handler**: `PushPlatform._handleIncomingMessage` → `PushNotificationListener` → `OpenFromPushTap`.

**MUST NOT**: fragment o messaggi con UUID peer.

---

## 4. Persistenza client (non-SW)

### 4.1 Pending open chat (`localStorage`)

Chiave: `alfred_pending_open_chat`.

```json
{
  "recipientUserId": "<uuid>",
  "peerAddress": "<indirizzo>"
}
```

### 4.2 Launch fragment

```
#push-chat/{recipientUserId}/{peerAddress}
```

`peerAddress` URL-encoded se contiene `@`.

Costante: `PUSH_CHAT_FRAGMENT_PREFIX = 'push-chat/'`.

---

## 5. Diagrammi UML (sequenza)

| Diagramma | Flusso documentato |
|-----------|-------------------|
| [seq-push-received.puml](../../model/uml/notifications/seq-push-received.puml) | Delivery → Edge → SW → soppressione o notifica |
| [seq-suppression-sync.puml](../../model/uml/notifications/seq-suppression-sync.puml) | Client → `alfred_push_suppression` → RAM SW |
| [seq-notification-click.puml](../../model/uml/notifications/seq-notification-click.puml) | Tap → `open_chat` / cold start fragment |
| [seq-sync-subscriptions.puml](../../model/uml/notifications/seq-sync-subscriptions.puml) | Registrazione VAPID |

State machine: [notifications-sw-state.puml](../../model/uml/notifications/notifications-sw-state.puml), [notifications-client-state.puml](../../model/uml/notifications/notifications-client-state.puml).

*Nota: diagrammi UML vanno aggiornati post-implementazione per riflettere `peerAddress`.*

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
