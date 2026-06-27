# Alfred Client (Flutter)

Client ufficiale Alfred — multi-piattaforma (web, mobile, desktop).

## Stato

**Alpha** — collegato a Supabase (auth, contatti, inbox, chat realtime, profilo, multi-account).

| | |
|---|---|
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
├── models/      # ChatPeer, ChatMessage, …
├── services/    # InboxService, MessageService, ComposeService, …
├── providers/   # InboxController, MessagesController, …
├── screens/     # HomeScreen, …
└── widgets/     # InboxPanel, ChatPanel, …
```

Vedi `docs/decisions/address-based-messaging.md` e `PROJECT_MAP.md`.
