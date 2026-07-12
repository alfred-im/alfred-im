# Media in chat (voice, location)

**Contratto**: [SYS-MAILBOX](../specs/promises/system/SYS-MAILBOX.md)

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
