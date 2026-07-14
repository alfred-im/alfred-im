# Media in chat (voice, location, foto, video)

**Contratto**: [SYS-MAILBOX](../specs/promises/system/SYS-MAILBOX.md) · [PROM-CHAT-MEDIA](../specs/promises/product/PROM-CHAT-MEDIA.md)

---

## Foto (`image`)

| Campo | Valore |
|-------|--------|
| `content_type` | `image` |
| `media_mime` | `image/jpeg`, `image/png`, `image/webp` |
| `media_url` | bucket `chat-media` |
| `body` | didascalia opzionale |

Max **10 MB**. Path: `{userId}/{uuid}.{ext}`.

**HEIC/HEIF** (iPhone): accettato dal picker; conversione JPEG lato client prima dell’upload (`prepareImageForUpload`).

**UX** (`ChatInputBar`): allegato → galleria o fotocamera (`image_picker`); didascalia nel campo testo prima dell'invio. Bolla ottimistica con preview da `OutboundMediaCache` (`pending://`) **prima** della conversione/upload.

File: `message_media_service.dart` (`uploadImage`), `MessagesController.sendImage`, `prepare_image_for_upload_*.dart`

---

## Video (`video`)

| Campo | Valore |
|-------|--------|
| `content_type` | `video` |
| `media_mime` | `video/mp4`, `video/webm` |
| `media_url` | bucket `chat-media` |
| `duration_seconds` | obbligatorio |
| `body` | didascalia opzionale |

Max **50 MB**. Solo picker file (no registrazione).

**UX**: bolla video subito dopo la selezione file; byte letti in background; su web blob > 4 MB non persistiti in SharedPreferences (`ChatMediaConfig.webOutboundPersistMaxBytes`). Probe durata con timeout 6 s (`media_probe_timeout.dart`).

File: `video_message_content.dart`, `video_duration.dart`, `MessagesController.sendVideo` / `sendVideoFromPicker`

---

## Note vocali

| Campo | Valore |
|-------|--------|
| `content_type` | `voice` |
| `media_mime` | `audio/webm` (Opus) |
| `media_url` | bucket `chat-media` |
| `duration_seconds` | obbligatorio |

File: `{userId}/{uuid}.webm`. Web registra nativo; IO transcode FFmpeg.

**UX** (`ChatInputBar`): tieni premuto per registrare; rilascio invia (≥1s); swipe ↑ blocca; max 10 min.

File: `voice_recording_service.dart`, `voice_encoding_*.dart`, `MessageMediaService.uploadVoice`

---

## Posizione statica

| Campo | Valore |
|-------|--------|
| `content_type` | `location` |
| `latitude` / `longitude` | obbligatori, 5 decimali |

Nessun bucket — solo coordinate in Postgres.

**UX invio**: tap pin → anteprima mappa OSM a schermo intero; affinamento GPS; conferma invio.  
**UX ricezione**: tile OSM in bolla (`flutter_map`); tap apre OSM in browser.

File: `location_service.dart`, `LocationMessageContent`, `ChatInputBar` pin flow

---

## Verifica (gate)

| Livello | Artefatti |
|---------|-----------|
| SQL | `supabase/tests/mailbox_send_media_smoke.sql` |
| Dart unit | `messages_controller_media_test.dart`, `group_messages_controller_media_test.dart`, `chat_media_support_test.dart`, `image_bytes_test.dart`, `merge_chat_message_test.dart` |
| Dart widget | `message_bubble_test.dart` |
| Gate | `cd client && bash scripts/verify.sh` |
