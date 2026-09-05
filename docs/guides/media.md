# Media in chat (voice, location, foto, video)

**Regole prodotto:** [SYS-MAILBOX](../specs/promises/system/SYS-MAILBOX.md), [PROM-CHAT-MEDIA](../specs/promises/product/PROM-CHAT-MEDIA.md), [SURF-CHAT-014](../specs/surfaces/SURF-CHAT.md)

**Ultima revisione:** 2026-08-08

---

## Composer UX

`ChatInputBar` (`chat_input_bar.dart`)

| Elemento | Comportamento |
|----------|---------------|
| Graffetta | Un solo pulsante `attach_file` a sinistra apre un bottom sheet |
| Pannello media | Riga orizzontale scrollabile di pulsanti solo-icona (tooltip per a11y): galleria, fotocamera, video, GIF, posizione |
| Destra | Microfono (hold-to-record invariato) e invio testo restano a destra |
| Barra | GIF e posizione **non** sono più pulsanti separati nella barra — solo nel pannello graffetta |

File: `chat_input_bar.dart`

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

**UX** (`ChatInputBar`): graffetta → icona galleria o fotocamera nel pannello (`image_picker`); didascalia nel campo testo prima dell'invio. Bolla ottimistica con preview da `OutboundMediaCache` (`pending://`) **prima** della conversione/upload.

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

**UX**: graffetta → icona video nel pannello; bolla video subito dopo la selezione file; byte letti in background; su web blob > 4 MB non persistiti in SharedPreferences (`ChatMediaConfig.webOutboundPersistMaxBytes`). Probe durata con timeout 6 s (`media_probe_timeout.dart`).

File: `video_message_content.dart`, `video_duration.dart`, `MessagesController.sendVideo` / `sendVideoFromPicker`

---

## GIF (`gif`)

| Campo | Valore |
|-------|--------|
| `content_type` | `gif` |
| `media_url` | bucket `chat-media` |

**UX**: graffetta → icona GIF nel pannello; file picker `.gif` (`FilePicker`, `withData: true`); invio immediato senza didascalia separata.

File: `ChatInputBar._pickGif`, `MessagesController.sendGif`

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

**UX invio**: graffetta → icona posizione nel pannello → overlay mappa OSM a schermo intero; affinamento GPS; conferma invio.  
**UX ricezione**: tile OSM in bolla (`flutter_map`); tap apre OSM in browser.

File: `location_service.dart`, `LocationMessageContent`, `ChatInputBar._beginLocationShare`

---

## Verifica

| Livello | Artefatti | Ruolo |
|---------|-----------|--------|
| SQL | `supabase/tests/mailbox_send_media_smoke.sql` | Contratto RPC server |
| Dart unit/widget | `messages_controller_media_test.dart`, `chat_media_support_test.dart`, … | **Igiene CI** — non valida invio reale da galleria |
| **Release** | `bash scripts/test.sh e2e` | Browser + DB — percorso telefono (4 account + gruppo, galleria, resume) |

Vedi [docs/testing/strategy.md](../testing/strategy.md).
