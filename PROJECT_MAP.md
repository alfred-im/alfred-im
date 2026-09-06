# Alfred - Mappa Completa del Progetto

**Ultimo aggiornamento**: 2026-09-06  
**Stato**: stabile — senza versionamento release (pubspec Flutter default invariato)

**SSOT documentazione:** [docs/SSOT.md](docs/SSOT.md) — per ogni tipo di informazione, un solo file canonico; questo documento è **mappa sessione**, non duplica promesse/RPC/test.

---

## 📋 Indice

1. [Stato repository](#-stato-repository)
2. [Panoramica](#-panoramica-progetto)
3. [Architettura](#️-architettura)
4. [Struttura e responsabilità](#-struttura-file-e-responsabilità)
5. [Servizi esterni](#-servizi-esterni)
6. [Database e storage](#-database-e-storage)
7. [Build e testing](#-build-e-testing)
8. [Stato corrente](#-stato-corrente)

---

## ⚠️ Stato repository

| Elemento | Dettaglio |
|----------|-----------|
| **Ingresso pubblico** | `README.md` · https://alfred-im.github.io/ (`org-site/`) · `SECURITY.md` · `CODE_OF_CONDUCT.md` |
| **Client** | `client/` — Flutter **web (PWA)**, collegato a Supabase |
| **Web client** | https://alfred-im-web.fly.dev/ — nginx + gateway shell dinamica (`client/deploy/fly/`, `client/deploy/gateway/`, `scripts/fly-deploy-client.sh`) |
| **Deploy** | `org-site/` → `alfred-im.github.io` (`deploy-org-site.yml`, secret `ORG_SITE_PAT`); client Fly; gate `release-suite.yml` |
| **Piattaforma** | Supabase `tvwpoxxcqwphryvuyqzu` — schema dominio + RLS + RPC |
| **Bridge** | `bridge-xmpp/` · `bridge-matrix/` — stub health Fly.io (federazione non implementata) |
| **Cronologia merge** | `CHANGELOG.md` |
| **Spec (SDD)** | Registro promesse: `docs/specs/registry.md` — confine prodotto · SSOT: [docs/SSOT.md](docs/SSOT.md) |
| **Modello** | `docs/domain/` · `docs/model/uml/` · `client/lib/machines/` — 13 bounded context con stato **`verified`** o **`documented`**; torre DDD→UML→statechart con profili UML Client/Platform; gate `scripts/check-model-sync.sh`; indice: [bounded-contexts.md](docs/domain/bounded-contexts.md) |

**Project page:** https://alfred-im.github.io/ — sorgente `org-site/`, workflow `deploy-org-site.yml`.

**Try it (app):** https://alfred-im-web.fly.dev/ — panoramica: `README.md`.

**Deploy client:** **`bash scripts/fly-deploy-client.sh`** (richiede `flyctl`). Auto-deploy Fly **solo** se abilitato in dashboard (Deployments → GitHub → branch `main`, working dir `.`) — vedi `client/deploy/fly/README.md`. Push su GitHub **non** deploya Fly; CI fa solo smoke Docker. L'agente **non** attende il deploy Fly.

**Stack su `main`**: `client/` · `supabase/` · `bridge-xmpp/` · `bridge-matrix/`

---

## 📌 Panoramica Progetto

**Alfred** è software di messaggistica **consent-first** e **feminist-informed**: **Supabase + client Flutter web (PWA) + bridge Python** (federazione futura). Non è un «progetto Flutter»: Flutter è solo il client in `client/`.

### Caratteristiche attuali

- **Auth**: email + password (GoTrue); **username** obbligatorio in registrazione — identità IM pubblica; email non in rubrica/ricerca
- **Multi-account**: manifest con tutti gli account aperti; **una** sessione GoTrue in RAM (focus); switch = focus UI + restore connessione — ADR `docs/decisions/multi-account-parallel-sessions.md` · fix web PR #152
- **Contatti**: rubrica opzionale (interni + federati), **isolata** dalla messaggistica — promesse `SYS-CONTACTS`, `PROM-PERSONAL-CONTACTS`, `SURF-CONTACTS` · ADR `docs/decisions/address-based-messaging.md`
- **Ricezione filtrata**: allow list personale `reception_allowlist` — sempre attiva; lista vuota = nessun recapito; rifiuto silenzioso (✓ singola) — promesse `SYS-RECEPTION`, `PROM-RECEPTION-FILTER`, `SURF-ALLOWLIST`; toggle rapido anche da scheda profilo peer (tap avatar) — promesse `PROM-PEER-PROFILE`, `SURF-PEER-PROFILE`
- **Link condivisibili**: fragment `#indirizzo` / `#indirizzo/chat`; share di sistema da profilo peer e sidebar account — `PROM-SHAREABLE-LINK` (PR #178)
- **Gruppi**: account `profile_kind = group` con identità propria; partecipazione **solo** allow list bidirezionale (no membership); shell senza inbox; erogazione automatica verso allow list del gruppo; UI autore (avatar + nome) in chat — promessa `SYS-GROUP` (PR #162)
- **Messaggistica per indirizzo**: `username` (Alfred) o `user@server` (esterno, `unsupported` senza federazione); archivio **per titolare archivio** in `messages` (`archive_user_id`, `author_id`, `peer_profile_id`, `original_author_id`); inbox = `list_inbox()` on-read sul mio archivio; chat per `peer_profile_id`
- **Inbox + chat realtime**: Postgres + Realtime; ricerca liste on-demand — inbox, rubrica, persone consentite (`PROM-LIST-FILTER`, PR #132, #171)
- **GIF / voice / location / foto / video**: bucket `chat-media` per media; posizione statica (lat/lng in Postgres); `OutboundMessageQueue` per retry client — [PROM-CHAT-MEDIA](docs/specs/promises/product/PROM-CHAT-MEDIA.md)
- **Federazione**: outbox `queued` — attende bridge
- **Spunte**: `delivered_at` / `read_at` sulla copia mittente — ✓ = accettato server; ✓✓/blu via worker [SYS-DELIVERY](docs/specs/promises/system/SYS-DELIVERY.md) (`deliver` + `read_receipt` outbox); lettura locale `mark_peer_read` sul destinatario — promesse `SYS-MAILBOX`, `PROM-MESSAGE-STATUS`
- **Reazioni messaggio**: overlay reazioni su tap messaggio — `PROM-MESSAGE-REACTIONS` (PR #246)
- **@mentions**: evidenziazione e navigazione @username in chat — `PROM-MESSAGE-MENTION`
- **Brand**: `#2D2926`, layout responsive stile WhatsApp Web

### Tecnologie

| Categoria | Tecnologia |
|-----------|------------|
| Client | Flutter web (PWA) · Dart 3.12 |
| Piattaforma | Supabase (Postgres, Auth, Realtime, Storage) |
| Bridge | Python 3.12 + aiohttp (Fly.io) |
| CI | GitHub Actions — `release-suite`, `spec-sync`, `docker-client-fly` |

---

## 🏗️ Architettura

```
┌─────────────────────────────┐
│   Flutter web (client/)     │  ← UI; solo piattaforma
└──────────────┬──────────────┘
               │
┌──────────────▼──────────────┐
│   Supabase (piattaforma)    │
└──────┬──────────────┬───────┘
       │              │
┌──────▼──────┐ ┌─────▼──────┐
│ bridge XMPP │ │bridge Matrix│  ← stateless; stato in Supabase
└─────────────┘ └────────────┘
```

- **Bridge stateless**: `docs/decisions/bridge-stateless.md`
- **Chat unificate** (nessuna distinzione interna/esterna): `docs/decisions/no-internal-external-chat-distinction.md`
- **Dettaglio completo**: `docs/architecture/full-stack.md`
- **Modello caselle (mailbox)**: `docs/architecture/mailbox-inbox-outbox-spec.md` — archivio per titolare archivio + outbox; promesse `SYS-MAILBOX`, `SYS-ACCOUNT-BOUNDARY`, `SYS-DELIVERY` (PR #159, #179)

---

## 📂 Struttura File e Responsabilità

### Root

```
/workspace/
├── README.md               # Ingresso pubblico GitHub (consent-first)
├── SECURITY.md             # Policy vulnerabilità
├── CODE_OF_CONDUCT.md      # Contributor Covenant
├── client/                 # Client Flutter web (PWA) — deploy Fly (`client/deploy/fly/`)
├── supabase/               # Migrazioni e config piattaforma
├── bridge-xmpp/            # Demone bridge XMPP (stub)
├── bridge-matrix/          # Demone bridge Matrix (stub)
├── docs/                   # Documentazione tecnica AI
│   ├── domain/             # DDD + Event Storming (significato)
│   └── model/uml/          # UML 2.5 PlantUML (forma)
├── fly.toml, Dockerfile    # Deploy bridge Fly.io
├── PROJECT_MAP.md          # Questo file
└── .cursor/                # Regole agente Cursor
    └── rules/
        └── main.mdc            # Regole sviluppo AI (SSOT processo, alwaysApply)
```

### Client Flutter (`client/`)

| Elemento | Dettaglio |
|----------|-----------|
| **Entry** | `lib/main.dart` → `AppShell` → `HomeScreen` (sempre shell; overlay auth se 0 account o «Aggiungi account») |
| **State** | **Macchine** (`client/lib/machines/<context>/`) + **coordinatori** (`client/lib/coordinators/`) + controller UI sottili; composition root: `AuthController` |
| **Backend** | `SupabaseClient` della sessione in **focus** (una GoTrue attiva) — REST + Realtime + RPC |
| **Config** | `lib/config/app_config.dart` — `--dart-define=SUPABASE_URL` |
| **Gate CI** | `scripts/verify.sh` — igiene: sync spec/modello + analyze + test Dart isolati (**non** valida il prodotto) |
| **Build web** | Locale: `flutter build web --base-href "/"`. Release Fly: `--pwa-strategy=none` + CanvasKit in immagine — vedi `client/deploy/fly/README.md` § Build web e avvio |

**Non deducibile — client layering**: `coordinators/` — `auth_session`, `push`, `contacts`, `profile`, `reception`, `inbox`, `messaging`, `navigation`, `group_home`, `group_messages`, `shareable_link` (facade UI → macchina + effetti). `adapters/external_intent_adapter.dart` — **unico ingresso** push tap / link `#` / compose → `NavigationMachine`. Messaggistica 1:1: tre macchine (`ConversationLoadMachine`, `OutboundSendMachine`, `RealtimeAttachmentMachine`) composte da `MessagingCoordinator` in `coordinators/` (facade: `MessagesController`).

**Non deducibile — multi-account client**: `MultiAccountMachine` **possiede** `focusUserId` (intent focus); `AccountManager` esegue dispose/restore GoTrue via effetti. Manifest `alfred_saved_accounts` elenca **tutti** gli account aperti; in RAM **al massimo una** `AccountSession` GoTrue (quella in focus). Storage auth per account: `SharedPreferencesLocalStorage` → `alfred_auth_{userId}`. Persistenza **dichiarativa** per entry (`persistOpenAccount` / `upsertAccount` al login e `tokenRefreshed` — **vietato** `saveAllAccounts` nel runtime). **Boot:** `bootstrapManifest` → `switchToAccount(deferInboxLoad: true)` → `sessionReady` → inbox in background (`refreshFocusedInboxSilently`). **Vista UI** (`AccountViewState` per `userId`): mutazione **solo** via `AccountViewStateStore` (`client/lib/stores/`) — chat aperta + inbox/chat su mobile **indipendenti per account**. Inbox: `InboxCoordinator` + `InboxController` (macchina in `machines/inbox/`). Coda invio: `userId|peerProfileId`. Overlay credenziali su `HomeScreen`. Doc: `docs/guides/multi-account.md`, `docs/decisions/multi-account-parallel-sessions.md`.

**Non deducibile — auth bootstrap**: login/add-account usa client effimero; **non** chiamare `signOut` sul bootstrap dopo adozione sessione dedicata (revoca refresh GoTrue). PKCE: `EphemeralPkceStorage`. **Chiudi account** = logout **solo locale** (`close()` cancella storage, nessuna `POST /auth/v1/logout`). Doc: `docs/guides/multi-account.md`.

**Non deducibile — layout inbox**: `HomeScreen` — mobile drawer `AccountSidebar`; desktop colonna sinistra account + inbox. `AccountSidebar`: chiusura account in card profilo. `InboxPanel`: ricerca on-demand ([PROM-LIST-FILTER](docs/specs/promises/product/PROM-LIST-FILTER.md), [SURF-INBOX](docs/specs/surfaces/SURF-INBOX.md)), `ValueKey(userId)` al cambio focus. Doc: `docs/guides/inbox.md`.

**Non deducibile — ingresso chat 1:1**: `OpenConversation` in due fasi ([PROM-CONVERSATION-SCOPE-009–012](docs/specs/promises/product/PROM-CONVERSATION-SCOPE.md), [SURF-CHAT-016](docs/specs/surfaces/SURF-CHAT.md)): **fase A sync** — `AccountNavigationEffects._enterConversationUi` imposta view-state (`activePeer`, shell mobile chat) e committa scope solo se sessione già in RAM; UI `ChatIngressPanel` (header peer + back + spinner) via `ConversationScopePane`. **Fase B async** — `SessionAuthority.ensureFocusReady`, re-commit scope, `LoadMessages`, `refreshFocusedInboxSilently` (`InboxController.load(showLoadingIndicator: false)`); abort se utente esce o cambia peer (`_ingressPrepGeneration`). Su mobile: AppBar recovery (`Riconnessione…`) solo se **non** in shell chat (`home_screen.dart`). UML: `docs/model/uml/navigation/seq-open-conversation-unified.puml`, `docs/model/uml/multi-account/seq-run-as-focus.puml`. Test: `conversation_scope_ingress_test.dart`, `navigation_open_ingress_test.dart`.

**Non deducibile — chat**: `AnchoredMessageList` (`ListView` reverse, soglia 48 px). Storico iniziale = ultimi 100 messaggi (`list_peer_messages` senza cursore); scroll verso l'alto → `loadOlderMessages()` + `p_before_created_at`; anteprima inbox sempre nella prima finestra (SYS-MAILBOX-057 / SURF-CHAT-015). Doc: `docs/guides/chat-scroll.md`, `docs/specs/contracts/rpc.md`.

**Non deducibile — voice / location**: hold-to-send WebM/Opus; posizione statica con anteprima mappa OSM. Doc: `docs/guides/media.md`.

**Non deducibile — profilo pubblico UI**: `ProfileSummary` (`lib/models/profile_summary.dart`) — unico modello per nome, username, avatar, pronomi, `profileKind` (`user`/`group`); usato da `UserProfile.summary`, `OpenAccount.profile`, `ChatPeer.profile`. Promesse: `SYS-PROFILE`, `PROM-PROFILE-IDENTITY`, `SURF-PROFILE`, `SYS-GROUP`. Fetch batch: `ProfileService.fetchSummariesByIds`. Widget condivisi: `ProfileAvatar`, `ProfileIdentityLines` (`lib/widgets/profile_identity.dart`). **Scheda profilo peer**: tap avatar → `showPeerProfileOverlay` — doc `docs/guides/peer-profile.md`.

**Non deducibile — shell gruppo**: focus su account `group` → `HomeScreen` nasconde inbox; `GroupConversationScreen` (storico unico + broadcast); allow list e profilo come account umano; layout mobile full-width sotto 720px. Chat con peer gruppo (account `user`): `MessagesController` con `peerIsGroup` + etichette autore (`MessageAuthorHeader`, `author_display.dart`). Doc: `docs/guides/groups.md`, promessa `SYS-GROUP`.

**Non deducibile — coda invio client**: `OutboundMessageQueue` ≠ outbox server federato.

---

## 🌐 Servizi Esterni

### Supabase (`tvwpoxxcqwphryvuyqzu`, EU)

- Config: `supabase/config.toml`, `supabase/migrations/`
- MCP agente: `execute_sql`, `apply_migration`, `list_migrations`
- **Non deducibile — bootstrap client a due strati**: (1) `config.json` al deploy — cablaggio obbligatorio (`supabaseUrl`, `supabaseAnonKey`, `publicBaseUrl`); letto prima di ogni RPC; non editabile da owner perché senza wiring non c'è connessione al backend. (2) `instance_config` in Supabase — identità istanza (`im_server_id`, branding, legali); RPC `get_instance_bootstrap` / `upsert_instance_config` dopo il cablaggio. **Due domini HTTP per istanza** (possono coincidere): URL pubblico (`publicBaseUrl`) vs dominio federativo (`instance.im_server_id`). SSOT: `client/deploy/fly/README.md` § Configurazione istanza.
- **Non deducibile — redirect auth email**: `signUp` / `resetPasswordForEmail` passano `emailRedirectTo`/`redirectTo` da `AuthRedirectUrl.resolve()` (`client/lib/utils/auth_redirect_url.dart`) — su web usa `publicBaseUrl` da `config.json` (origine corrente su localhost). Dashboard Supabase → Auth → URL Configuration: **Redirect URLs** deve includere l'host di `publicBaseUrl` (demo: `https://alfred-im-web.fly.dev/**`; rimuovere `XmppTest/**` e vecchi URL GitHub Pages se presenti); **Site URL** resta `http://localhost:3000` come **canarino** (fallback se `redirect_to` manca — segnale errore, non destinazione prodotto; promessa `SURF-AUTH-013`). Vedi `supabase/config.toml`.

### Fly.io (`alfred-im`, `fra`)

| Bridge | Health |
|--------|--------|
| XMPP | `https://alfred-im.fly.dev/health` |
| Matrix | `https://alfred-im.fly.dev:8081/health` |

Avvio container: `scripts/start-bridges.sh` (`CMD ["/bin/sh", "/start.sh"]`). Deploy: `scripts/fly-deploy-all.sh`. Client web Fly: `client/deploy/fly/` + `scripts/fly-deploy-client.sh`. Gate CI: `bash scripts/docker-smoke.sh` (workflow `docker-bridges.yml`), `bash scripts/docker-smoke-client.sh` (`docker-client-fly.yml`).

**Migrazione nome app (una tantum da `xmpptest`)**: `bash scripts/fly-rename-app.sh` poi redeploy.

---

## 💾 Database e Storage

**Fonte di verità messaggistica**: tabella `messages` (archivio per `archive_user_id`) + `profiles`. Inbox = aggregazione on-read (`list_inbox()`). Invio: RPC account scrive **solo** copia mittente + accoda `outbox`; worker `alfred_delivery.process_outbox` materializza destinatario, `delivered_at`/`read_at` mittente e erogazione gruppo ([SYS-ACCOUNT-BOUNDARY](docs/specs/promises/system/SYS-ACCOUNT-BOUNDARY.md), [SYS-DELIVERY](docs/specs/promises/system/SYS-DELIVERY.md)).

| Storage | Uso |
|---------|-----|
| Postgres | `profiles`, `contacts`, `reception_allowlist`, `messages`, `outbox`, `sync_cursors`, `bridge_jobs`, `push_subscriptions`; schema worker `alfred_delivery` |
| Storage `chat-media` | GIF, voice WebM, image, video (`{userId}/{uuid}.…`) |
| Storage `avatars` | Foto profilo (`{userId}/avatar.{jpg\|png\|webp}`, max 2 MB) |
| Storage `instance-branding` | Logo/favicon istanza owner (`branding/{logo\|favicon}/{uuid}.ext`, max 2 MB; scrittura solo owner) |
| Client `SharedPreferences` | Account aperti (`OpenAccount` + refresh token) e `focusUserId` |

RPC principali: `list_inbox`, `find_profile_by_username`, `send_message_to_profile`, `list_peer_messages`, `list_archive_messages`, `broadcast_message_to_allowlist`, `mark_peer_read`.

Dettaglio schema, RLS, trigger: `docs/architecture/full-stack.md` §4 e [contracts/schema.md](docs/specs/contracts/schema.md).

---

## 🔧 Build e Testing

```bash
cd client
bash scripts/verify.sh           # gate CI — igiene codice (obbligatorio prima del push)
bash scripts/test.sh e2e         # e2e locale — obbligatorio a fine lavoro su client/
bash scripts/verify.sh --build   # + build web
bash scripts/test.sh e2e  # release — valida il prodotto (browser + DB)
bash scripts/test.sh release       # stack locale completo (alias: manual, ci)
```

- **Test:** SSOT comandi → [client/scripts/test/README.md](client/scripts/test/README.md); filosofia gate vs release → [docs/testing/strategy.md](docs/testing/strategy.md)
- **Gate CI** (`verify.sh`): lint + test Dart isolati — non sostituisce test sul telefono
- CI gate: `release-suite.yml` → `verify.sh`; smoke client Fly: `docker-client-fly.yml`
- E2E: `client/e2e/` (Playwright)
- SQL smoke: `delivery_ticks_smoke.sql`, `mailbox_*.sql`, `reception_allowlist_*.sql`, `group_*.sql`, `rpc_helper_security_smoke.sql`, `send_message_to_profile_smoke.sql`
- Integrazione spunte: `bash scripts/test.sh integration-ticks` (contratto ✓ / ✓✓ / allow list)

---

## 📊 Stato Corrente

### Implementato

| Area | Stato |
|------|-------|
| Auth, profilo, multi-account, scheda profilo peer, link condivisibili | ✅ |
| Contatti, inbox, chat testo/GIF/voice/location/foto/video, Web Push | ✅ |
| Modello caselle + delivery plane | ✅ |
| Account gruppo (shell, erogazione, UI autore) | ✅ |
| Ricerca inbox on-demand, aggancio al fondo | ✅ |
| Schema Supabase + RLS + RPC | ✅ |
| Deploy Pages + gate CI `verify.sh` (igiene) | ✅ |
| Bridge federazione | 🟡 Stub health only |

### Prossimi passi

- Bridge XMPP/Matrix (consume `outbox`, `sync_cursors`) — `docs/architecture/full-stack.md`
- Spunte federate via bridge

### Design system

- Colore: `#2D2926` — `client/lib/theme/alfred_colors.dart`
- Logo: `client/lib/widgets/alfred_logo.dart`

---

## Riferimento operativo

### Allow list ricezione

Regole prodotto: [SYS-RECEPTION](docs/specs/promises/system/SYS-RECEPTION.md), [PROM-RECEPTION-FILTER](docs/specs/promises/product/PROM-RECEPTION-FILTER.md), [SURF-ALLOWLIST](docs/specs/surfaces/SURF-ALLOWLIST.md). Semantica spunte: [server-as-reception.md](docs/decisions/server-as-reception.md).

### Spunte (delivery plane)

Regole prodotto: [SYS-MAILBOX](docs/specs/promises/system/SYS-MAILBOX.md), [PROM-MESSAGE-STATUS](docs/specs/promises/product/PROM-MESSAGE-STATUS.md), [SYS-DELIVERY](docs/specs/promises/system/SYS-DELIVERY.md). Semantica UI: [server-as-reception.md](docs/decisions/server-as-reception.md).

Test: `bash scripts/test.sh integration-ticks`

### Gate CI (igiene)

`verify.sh` — sync spec/modello + analyze + test Dart isolati (**481**). **Non** valida il prodotto. Smoke SQL server: `delivery_ticks_smoke.sql`, `mailbox_*.sql`, …

Validazione release: `bash scripts/test.sh e2e` · catalogo in [client/scripts/test/README.md](client/scripts/test/README.md)

### File chiave client

| Area | Path |
|------|------|
| Composition root | `client/lib/providers/auth_controller.dart` |
| Coordinatori | `client/lib/coordinators/` |
| Intent esterni | `client/lib/adapters/external_intent_adapter.dart` |
| Focus account | `client/lib/machines/multi-account/multi_account_machine.dart` |
| View-state UI | `client/lib/stores/account_view_state_store.dart` |
| Messaggistica 1:1 | `client/lib/coordinators/messaging_coordinator.dart` |
| Inbox | `client/lib/coordinators/inbox_coordinator.dart` |
| Multi-account I/O | `client/lib/services/account_manager.dart` |
| Invio / spunte UI | `peer_message_service.dart`, `message.dart`, `message_bubble.dart` |

### Limiti noti

Badge non letti su icona app; realtime account non in focus; multi-tab stesso browser: last-write-wins.

---

## Cronologia

Dettaglio merge e revisioni: **`CHANGELOG.md`**.

**Riferimenti**: `README.md`, `docs/INDICE.md`, `docs/specs/registry.md`, `CHANGELOG.md`
