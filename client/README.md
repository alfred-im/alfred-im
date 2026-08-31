# Alfred Client (Flutter web)

Client ufficiale Alfred — **Flutter web** (installabile come **PWA** su browser desktop e mobile).

Panoramica repository: [`../README.md`](../README.md)

## Stato

Client web collegato a Supabase (contatti, inbox, chat realtime, profilo, **multi-account**).

| | |
|---|---|
| **Multi-account** | Manifest con tutti gli account aperti; **una** sessione GoTrue in RAM (focus); switch = focus UI + restore |
| **Auth** | Overlay su shell (`AuthOverlay`), non schermata piena |
| **Try it** | https://alfred-im-web.fly.dev/ |
| **Owner / branding** | Pannello configurazione server — shell PWA + upload logo/favicon (`SURF-INSTANCE-CONFIG`) |
| **Deploy** | Fly: `bash scripts/fly-deploy-client.sh` — vedi `deploy/fly/README.md` |
| **Layout** | Lista inbox + chat (stile WhatsApp Web) |
| **Inbox** | RPC `list_inbox()` — aggregazione on-read su `messages` |
| **Chat** | Identificata da `peer_profile_id` (`ChatPeer`) |
| **Media** | Testo, GIF, voice (WebM/Opus), foto, video, location (mappa OSM) |
| **Web Push** | Notifiche browser (VAPID) — `SYS-PUSH` |
| **Nuovo messaggio** | FAB → username → stessa chat (vuota o con storico) |
| **Ricezione** | Allow list personale (`reception_allowlist`) — UI «Persone consentite» + toggle in scheda profilo peer (tap avatar) |
| **Profilo peer** | Overlay fullscreen al tap avatar — Allow + rubrica + CTA «Inizia a chattare» + Condividi — `PROM-PEER-PROFILE`, `SURF-PEER-PROFILE` |
| **Link condivisibili** | Fragment `#username` / `#username/chat`; share di sistema — `PROM-SHAREABLE-LINK` |
| **Gruppi** | Account `profile_kind = group`; `GroupHomePanel` + chat; partecipazione allow list bidirezionale — `SYS-GROUP` |
| **Reazioni** | Tap messaggio → overlay reazioni — `PROM-MESSAGE-REACTIONS` |
| **@mentions** | Evidenziazione e navigazione @username in chat — `PROM-MESSAGE-MENTION` |
| **Invio** | `send_message_to_profile` |
| **Gate test** | `verify.sh` — **481** test unit/widget (zero issue analyze) |

Build native mobile/desktop non è focus del progetto oggi; la superficie supportata è il web client.

## Test

**SSOT:** [scripts/test/README.md](scripts/test/README.md) · [docs/testing/strategy.md](../docs/testing/strategy.md)

```bash
cd client
bash scripts/test.sh list        # catalogo
bash scripts/test.sh gate        # gate CI — obbligatorio prima di push
bash scripts/test.sh flusso-reale  # release — percorso telefono
bash scripts/test.sh release       # stack locale (alias manual)
```

Gate: `bash scripts/verify.sh`

## Struttura

```
lib/
├── models/        # ChatPeer, ChatMessage, OpenAccount, …
├── machines/      # Statechart per bounded context (multi-account, messaging, navigation, …)
├── coordinators/  # Facade UI → macchina + effetti (auth, push, contacts, messaging, …)
├── adapters/      # Ingresso intent esterni (push tap, link #, compose)
├── services/      # AccountManager, AccountSession, InboxService, …
├── screens/       # HomeScreen (shell), GroupConversationScreen, AppShell, …
├── providers/     # AuthController, InboxController, GroupMessagesController, MessagesController, …
└── widgets/       # AuthOverlay, InboxPanel, ChatPanel, PeerProfileOverlay, …
```

## Local Supabase (optional)

Isolated backend for writes/tests: `supabase start` from repo root, then launch the client with `--dart-define=SUPABASE_URL=http://localhost:54321` and the local anon key from `supabase status`. Full steps: [AGENTS.md](../AGENTS.md) (Whole-stack local dev) and [`scripts/test/README.md`](scripts/test/README.md).

## Documentazione

Vedi [`../docs/guides/multi-account.md`](../docs/guides/multi-account.md), [`../docs/guides/groups.md`](../docs/guides/groups.md), [`../docs/guides/peer-profile.md`](../docs/guides/peer-profile.md), [`../docs/decisions/multi-account-parallel-sessions.md`](../docs/decisions/multi-account-parallel-sessions.md), [`../PROJECT_MAP.md`](../PROJECT_MAP.md).
