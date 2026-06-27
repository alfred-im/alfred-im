# Alfred Client (Flutter)

Client ufficiale Alfred — multi-piattaforma (web, mobile, desktop).

## Stato

**Alpha** — collegato a Supabase (auth, contatti, conversazioni, chat realtime, profilo, multi-account).

| | |
|---|---|
| **Live (Alpha dev)** | https://alfred-im.github.io/XmppTest/ — non è produzione |
| **Layout** | Lista conversazioni + chat (stile WhatsApp Web) |
| **Brand** | `#2D2926` |
| **Inbox** | RPC `list_conversations` — un round-trip (PR #112) |
| **Multi-account** | Switch Thunderbird via `SharedPreferences` (PR #111) |
| **Chat scroll** | Aggancio al fondo — `AnchoredMessageList` (PR #125) |
| **GIF** | Upload bucket `chat-media` (PR #115) |
| **Note vocali** | WebM/Opus, hold-to-send, player inline (PR #126) |
| **Retry invio** | `OutboundMessageQueue` — testo, GIF, voice |
| **Pages** | Richiede script passkeys in `web/index.html` (PR #110) |

## Test

```bash
cd client
bash scripts/verify.sh            # analyze + test (gate CI)
bash scripts/verify.sh --build    # + build web
npx playwright test e2e/          # e2e (inbox-load)
```

## Sviluppo

```bash
cd client
bash scripts/verify.sh
flutter run -d chrome \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

## Build web (GitHub Pages / Alpha)

```bash
flutter build web --release --base-href "/XmppTest/"
```

Il workflow `.github/workflows/deploy-pages.yml` esegue `scripts/verify.sh` (analyze + test) + build + job **`deploy-alpha`** su ogni **PR** su `main` e su ogni **push** a `main` (path `client/**`). Richiede Environment GitHub `github-pages` con *Deployment branches: All branches*.

## Struttura

```
lib/
├── config/      # AppConfig, VoiceConfig
├── models/      # Conversation, ChatMessage, OutboundQueueItem, …
├── services/    # Auth, MessageService, MessageMediaService, VoiceRecordingService,
│                # OutboundMessageQueue, voice_encoding_*, …
├── providers/   # ChangeNotifier (Auth, Conversations, Messages, …)
├── screens/     # AppShell, Auth, Home, Contatti, Profilo
├── utils/       # ConversationScrollAnchor, date_format, duration_format, …
└── widgets/     # AnchoredMessageList, ChatPanel, ChatInputBar, VoiceMessageContent, …
```

## Architettura client

- `docs/architecture/alpha-full-stack.md` — flussi auth, inbox, realtime, GIF, voice (§2.11), aggancio al fondo (§2.10), deploy Alpha (§6)
- `docs/implementation/voice-notes.md` — contratto voice, UX registrazione, Supabase
- `docs/design/conversation-bottom-anchor.md` — specifica scroll ancorato in chat
- `docs/architecture/alpha-pr-registry.md` — registro PR Alpha e checklist documentazione
- `docs/fixes/flutter-inbox-stability.md` — fix stabilità inbox (PR #113/#114)

## Prossimi passi

1. Bridge XMPP/Matrix (outbox già in schema; payload voice incluso)
2. Encryption token multi-account
3. Spunte federate (XEP via bridge)

Vedi `PROJECT_MAP.md` e `docs/decisions/project-revolution-discovery.md`.
