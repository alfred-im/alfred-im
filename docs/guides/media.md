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

**UX** (`ChatInputBar`): allegato → galleria o fotocamera (`image_picker`); didascalia nel campo testo prima dell'invio.

File: `message_media_service.dart` (`uploadImage`), `MessagesController.sendImage`

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

File: `video_message_content.dart`, `video_duration.dart`, `MessagesController.sendVideo`

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
