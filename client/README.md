# Alfred Client (Flutter)

Client ufficiale Alfred — multi-piattaforma (web, mobile, desktop).

## Stato

**Alpha** — collegato a Supabase (auth, contatti, conversazioni, chat realtime, profilo, multi-account).

| | |
|---|---|
| **Live** | https://alfred-im.github.io/XmppTest/ |
| **Layout** | Lista conversazioni + chat (stile WhatsApp Web) |
| **Brand** | `#2D2926` |
| **Inbox** | RPC `list_conversations` — un round-trip |

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
└── widgets/     # ConversationsPanel, ChatPanel, …
```

## Architettura client

Vedi `docs/architecture/alpha-full-stack.md` — flussi auth, inbox, realtime, multi-account.

## Prossimi passi

1. Bridge XMPP/Matrix (outbox già in schema)
2. Encryption token multi-account
3. Spunte federate (XEP via bridge)

Vedi `PROJECT_MAP.md` e `docs/decisions/project-revolution-discovery.md`.
