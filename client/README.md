# Alfred Client (Flutter)

Client ufficiale Alfred — multi-piattaforma (web, mobile, desktop).

## Stato

**Alpha** — collegato a Supabase (contatti, inbox, chat realtime, profilo, **multi-account con sessioni parallele**).

| | |
|---|---|
| **Multi-account** | `AccountManager` — un client Supabase per account aperto; switch = focus UI |
| **Auth** | Overlay su shell (`AuthOverlay`), non schermata piena |
| **Live (Alpha dev)** | https://alfred-im.github.io/XmppTest/ |
| **Layout** | Lista inbox + chat (stile WhatsApp Web) |
| **Inbox** | RPC `list_inbox()` — aggregazione on-read su `messages`; nessuna tabella/cache inbox |
| **Chat** | Identificata da `peer_profile_id` (`ChatPeer`) |
| **Nuovo messaggio** | FAB → username → stessa chat (vuota o con storico) |
| **Invio** | `send_message_to_profile` |

## Test

```bash
cd client
bash scripts/verify.sh            # obbligatorio prima di git push
npx playwright test e2e/
```

## Struttura

```
lib/
├── models/      # ChatPeer, ChatMessage, OpenAccount, …
├── services/    # AccountManager, AccountSession, InboxService, …
├── providers/   # AuthController, InboxController (per sessione), …
├── screens/     # HomeScreen (shell), AppShell, …
└── widgets/     # AuthOverlay, InboxPanel, ChatPanel, …
```

Vedi `docs/decisions/multi-account-parallel-sessions.md`, `docs/implementation/multi-account-client.md`, `PROJECT_MAP.md`.
