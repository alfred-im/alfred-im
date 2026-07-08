# Voice notes (WebM/Opus)

> **Contratto canonico**: [SYS-MAILBOX.md](../specs/promises/system/SYS-MAILBOX.md) — evidenza implementativa PR #126.

**Stato**: implementato in PR **#126**

## Contratto canonico

| Campo | Valore |
|-------|--------|
| `content_type` | `voice` |
| `media_mime` | `audio/webm` (Opus) — **unico formato** in storage |
| `media_url` | URL pubblico bucket `chat-media` |
| `duration_seconds` | intero > 0 (obbligatorio per `voice`) |
| `media_size_bytes` | opzionale; tetto bucket **15 MB** |

File storage: `{userId}/{uuid}.webm`.

**Scelta formato**: WebM/Opus ovunque; web registra nativo (MediaRecorder); IO transcode FFmpeg (`voice_encoding_io.dart`) prima dell'upload — niente formati multipli in piattaforma.

## UX registrazione (`ChatInputBar`)

| Gesto / stato | Comportamento |
|---------------|---------------|
| Campo vuoto | Pulsante **microfono** al posto di invia |
| Tieni premuto | Registra |
| Rilascio (non bloccato) | **Invio immediato** (se durata ≥ 1 s) |
| Swipe ↑ | Blocca registrazione |
| Swipe ↓ | Annulla |
| Bloccato | **Invia** in barra (invio immediato) o **Anteprima** nell'overlay → invia/cestino |
| Max durata | 10 min (`VoiceConfig.maxDurationSeconds`) |

## Client Flutter

| Area | File / componente |
|------|-------------------|
| Config | `lib/config/voice_config.dart` |
| Registrazione | `lib/services/voice_recording_service.dart` (`record`) |
| Transcode IO | `lib/services/voice_encoding_io.dart` / `voice_encoding_web.dart` |
| Upload | `MessageMediaService.uploadVoice` |
| Invio | `MessagesController.sendVoice` → RPC `send_message_to_profile` (8 argomenti) |
| Bolla | `lib/widgets/voice_message_content.dart` — play/pausa, waveform, durata (`just_audio`) |
| Coda retry | `OutboundMessageQueue` + `OutboundMediaCache` (web) — testo, GIF, **voice**; retry periodico + «Riprova invio» su bolle `failed` |

Dipendenze aggiunte: `record`, `just_audio`, `path_provider`, `ffmpeg_kit_flutter_new_min`, `http` (fetch blob URL su web).

Permessi: `RECORD_AUDIO` (Android), `NSMicrophoneUsageDescription` (iOS/macOS).

## Supabase

Migrazioni **due step** (enum PostgreSQL deve commitare prima dell'uso):

| File | Contenuto |
|------|-----------|
| `20260627120000_message_voice_support.sql` | `ALTER TYPE … ADD VALUE 'voice'` |
| `20260627120100_message_voice_support.sql` | colonne, CHECK, RPC, trigger, bucket |

- RPC `send_message_to_profile` overload 8 parametri; overload 5 arg delega
- `format_voice_preview` → preview inbox `🎤 m:ss`
- `on_message_inserted`: outbox payload include `duration_seconds`, `media_mime`, `media_size_bytes`
- `mark_peer_read`: include `content_type = voice`
- Bucket `chat-media`: MIME `image/gif`, `audio/webm`; `file_size_limit` 15 MB

`supabase/tests/schema_smoke.sql`: verifica overload RPC 8 argomenti.

## Bridge (futuro)

Outbox payload già include metadati voice. Il bridge scarica il blob WebM e adatta a Matrix/XMPP senza cambiare schema messaggi.

## CI / deploy Alpha

Stesso workflow delle altre feature client: `build` (analyze + test + compile) → `deploy-alpha` su https://alfred-im.github.io/XmppTest/.

| Aspetto | Dettaglio |
|---------|-----------|
| Ambiente | **Sviluppo/Alpha** — URL condiviso, non produzione |
| Trigger | PR su `main` + push `main` (path `client/**`) |
| Concurrency | `pages-alpha` — ultimo build vince |
| Vincolo GitHub | Settings → Environments → `github-pages` → *Deployment branches: All branches* |
| Errore tipico PR | `environment protection rules` se resta solo `main` |
| Verifica API | `deployment_branch_policy: null` = nessun vincolo branch |

Workflow storico: rimossi `deploy-preview` e `deploy-prod` (naming errato) a favore di un solo job `deploy-alpha`.

**PR correlate**: #126 (voice + deploy-alpha), #127 (`client/scripts/verify.sh` — gate `flutter analyze` locale/CI).

Vedi `alpha-full-stack.md` §5–§6, `PROJECT_MAP.md` § Build e Testing.
