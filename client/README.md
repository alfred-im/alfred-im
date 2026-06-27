# Alfred Client (Flutter)

Client ufficiale Alfred — multi-piattaforma (web, mobile, desktop).

## Stato

**Alpha** — collegato a Supabase (auth, contatti, conversazioni, chat realtime, profilo, multi-account).

| | |
|---|---|
| **Live** | https://alfred-im.github.io/XmppTest/ |
| **Layout** | Lista conversazioni + chat (stile WhatsApp Web) |
| **Brand** | `#2D2926` |
| **Inbox** | RPC `list_conversations` — un round-trip (PR #112) |
| **Multi-account** | Switch Thunderbird via `SharedPreferences` (PR #111) |
| **Chat scroll** | Aggancio al fondo — `AnchoredMessageList` (PR #125) |
| **Pages** | Richiede script passkeys in `web/index.html` (PR #110) |

## Test

```bash
flutter test                    # unit + widget
cd client && npx playwright test e2e/   # e2e (inbox-load)
```

## Sviluppo

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

## Build web (GitHub Pages)

```bash
flutter build web --release --base-href "/XmppTest/"
```

Il workflow `.github/workflows/deploy-pages.yml` esegue test + build + deploy su push a `main`.

## Struttura

```
lib/
├── config/      # URL Supabase (--dart-define)
├── models/      # Conversation, ChatMessage, Contact, …
├── services/    # Auth, ConversationService (RPC), MessageService, …
├── providers/   # ChangeNotifier (Auth, Conversations, Messages, …)
├── screens/     # AppShell, Auth, Home, Contatti, Profilo
├── utils/       # ConversationScrollAnchor, date_format, …
└── widgets/     # AnchoredMessageList, ChatPanel, ConversationsPanel, …
```

## Architettura client

- `docs/architecture/alpha-full-stack.md` — flussi auth, inbox, realtime, multi-account, aggancio al fondo (§2.10)
- `docs/design/conversation-bottom-anchor.md` — specifica scroll ancorato in chat
- `docs/architecture/alpha-pr-registry.md` — registro PR Alpha e checklist documentazione
- `docs/fixes/flutter-inbox-stability.md` — fix stabilità inbox (PR #113/#114)

## Prossimi passi

1. Bridge XMPP/Matrix (outbox già in schema)
2. Encryption token multi-account
3. Spunte federate (XEP via bridge)

Vedi `PROJECT_MAP.md` e `docs/decisions/project-revolution-discovery.md`.
