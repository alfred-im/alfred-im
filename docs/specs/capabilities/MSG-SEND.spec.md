# MSG-SEND — Invio messaggi

| Campo | Valore |
|-------|--------|
| **Spec ID** | `MSG-SEND` |
| **Layer** | capability |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-03 |
| **ADR** | [address-based-messaging.md](../../decisions/address-based-messaging.md), [server-as-reception.md](../../decisions/server-as-reception.md) |
| **PR** | #115 (GIF), #126 (voice), #153 (location), #122 (delivered) |
| **Supersedes** | `implementation/voice-notes.md`, `implementation/location-sharing.md` (evidenza) |

Documento per AI — contratto invio unificato: un solo RPC, tipi contenuto, coda retry client.

---

## 1. Problema / obiettivo

L’utente invia messaggi a un account Alfred per `recipient_profile_id` (risolto da indirizzo). Il server è l’unico punto di invio; il client gestisce UI optimistic, upload media e retry.

---

## 2. Requisiti

### MUST

- **Unico punto invio server**: RPC `send_message_to_profile` — vedi [contracts/rpc.md](../contracts/rpc.md).
- Idempotenza client: `client_message_id` (UUID v4) su ogni invio.
- Stati consegna post-invio: vedi [MSG-READ](./MSG-READ.spec.md) (`sent` → `delivered` → `read`).
- Tipi `content_type` supportati su `main`: `text`, `gif`, `voice`, `location`.
- Upload media (GIF, voice) in bucket `chat-media` sotto `{auth.uid()}/{uuid}.*` prima dell’RPC.
- Coda retry client `OutboundMessageQueue` per testo, GIF, voice, location — retry periodico + «Riprova invio» su bolle `failed`.
- Indirizzo esterno `username@server`: rifiutato in Alpha con messaggio utente chiaro.

### SHOULD

- UI optimistic: bolla in lista prima della risposta RPC; merge su `client_message_id`.
- Preview inbox coerente con tipo (trigger / `format_*_preview` lato DB).

### MUST NOT

- RPC `send_message` legacy o overload ambigui (PostgREST).
- Invio a sé stessi (`recipient_profile_id = auth.uid()`).
- Invio testo vuoto (`content_type=text` e body vuoto).
- GIF/voice senza `media_url`; voice senza `duration_seconds` e `media_mime`.
- Location senza `latitude` e `longitude` in range valido.

---

## 3. Fuori scope

- Federazione / outbox consumer (bridge stub).
- Signed URL media (Alpha: URL pubblico bucket).
- Posizione live, reverse geocoding.
- Eliminazione messaggi.

---

## 4. Contratto

### 4.1 Tipi contenuto

| `content_type` | Campi obbligatori | Storage | Preview inbox |
|----------------|-------------------|---------|---------------|
| `text` | `body` non vuoto | — | testo troncato |
| `gif` | `media_url` | `chat-media`, max 10 MB, `image/gif` | `[GIF]` |
| `voice` | `media_url`, `duration_seconds` > 0, `media_mime` (`audio/webm`) | `{userId}/{uuid}.webm`, max 15 MB | `🎤 m:ss` |
| `location` | `latitude` [-90,90], `longitude` [-180,180] | Postgres only | `📍 Posizione` |

Coordinate arrotondate a 5 decimali lato client (`LocationConfig.coordinateDecimals`).

### 4.2 Backend

- Firma RPC: 10 parametri (location) — [contracts/rpc.md](../contracts/rpc.md).
- `on_message_inserted`: internal → `delivered`; federato → riga `outbox` con payload esteso (voice/location metadata).
- `mark_peer_read` include tutti i `content_type` sopra.

Migrazioni: `20260624230000_message_gif_support.sql`, `20260627120100_message_voice_support.sql`, `20260702120100_message_location_support.sql`, `20260627220000_fix_send_message_to_profile_overload.sql`.

### 4.3 Client

| Area | File / componente |
|------|-------------------|
| Invio testo | `MessagesController.sendText` → `ComposeService` / RPC |
| GIF | `MessageMediaService.uploadGif` → RPC `content_type=gif` |
| Voice | `VoiceRecordingService`, `uploadVoice`, `VoiceMessageContent` |
| Location | `LocationService` stream → anteprima obbligatoria → `sendLocation` |
| Coda | `OutboundMessageQueue`, `OutboundMediaCache` (web) |
| UI stato | `MessageBubble` / `MessageStatus` (✓ / ✓✓ / ✓✓ blu) |

### 4.4 UX invio (voice / location)

**Voice** (`ChatInputBar`): microfono se campo vuoto; tieni premuto registra; rilascio invia (≥1s); swipe ↑ blocca; max 10 min.

**Location**: tap pin → overlay anteprima mappa; Invia disabilitato fino a prima coordinata; Invia usa coordinate al tap; Annulla chiude senza invio.

---

## 5. Verifica

| Tipo | Riferimento |
|------|-------------|
| Gate | `cd client && bash scripts/verify.sh` |
| Smoke RPC | `supabase/tests/send_message_to_profile_smoke.sql`, overload 8/10 arg in `schema_smoke.sql` |
| Integrazione | `bash scripts/test.sh integration` |
| E2E | `bash scripts/test.sh e2e-multi` |

---

## 6. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [voice-notes.md](../../implementation/voice-notes.md) | Dettaglio voice |
| [location-sharing.md](../../implementation/location-sharing.md) | Dettaglio location |
| [alpha-full-stack.md](../../architecture/alpha-full-stack.md) §2.7–2.13 | Panoramica |
| [MSG-INBOX](./MSG-INBOX.spec.md) | Inbox dopo invio |

**Codice**: `client/lib/providers/messages_controller.dart`, `services/message_service.dart`, `services/outbound_message_queue.dart`, `widgets/chat_input_bar.dart`
