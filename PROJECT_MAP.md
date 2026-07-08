# Alfred - Mappa Completa del Progetto

**Ultimo aggiornamento**: 2026-07-08 (SDD #172; epurazione doc legacy)  
**Versione repository**: 3.2.0-alpha (client Flutter + piattaforma Supabase; bridge stub)

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

## ⚠️ Stato repository (2026-07-08)

| Elemento | Dettaglio |
|----------|-----------|
| **Client** | `client/` — Flutter, collegato a Supabase |
| **URL live** | https://alfred-im.github.io/XmppTest/ — **Alpha/sviluppo, non produzione** |
| **Deploy** | `.github/workflows/deploy-pages.yml` — `verify.sh` + build; job `deploy-alpha` (**PR su `main` e push su `main`**, path `client/**`) |

**Non è produzione**: https://alfred-im.github.io/XmppTest/ è solo l’istanza **Alpha** su GitHub Pages (demo, test, CI). Non confonderla con un futuro ambiente di produzione Alfred, che avrà URL e pipeline dedicati.

**Non deducibile — URL Alpha ≠ branch `main`**: https://alfred-im.github.io/XmppTest/ pubblica l’**ultimo** `deploy-alpha` riuscito (PR o push). **Non** è vero che «il sito live builda sempre da `main`». Per sapere quale codice è live, controllare quale workflow/PR ha deployato per ultimo (`concurrency: pages-alpha` → ultimo vince).
| **Piattaforma** | Supabase `tvwpoxxcqwphryvuyqzu` — schema dominio + RLS + RPC |
| **Bridge** | `bridge-xmpp/` · `bridge-matrix/` — stub health Fly.io (federazione non implementata) |
| **PR Alpha** | **#108–#172** su `main` — registro `docs/architecture/alpha-pr-registry.md` (#171 ricerca liste; #172 epurazione doc) |
| **Spec (SDD)** | Registro promesse: `docs/specs/registry.md` — `SYS-*`, `PROM-*`, `SURF-*` |

**Stack su `main`**: `client/` · `supabase/` · `bridge-xmpp/` · `bridge-matrix/`

---

## 📌 Panoramica Progetto

**Alfred** è una piattaforma di messaggistica: **Flutter + Supabase + bridge Python** (federazione futura).

### Caratteristiche attuali

- **Auth**: email + password (GoTrue); **username** obbligatorio in registrazione — identità IM pubblica; email non in rubrica/ricerca
- **Multi-account**: manifest con tutti gli account aperti; **una** sessione GoTrue in RAM (focus); switch = focus UI + restore connessione — ADR `docs/decisions/multi-account-parallel-sessions.md` · fix web PR #152
- **Contatti**: rubrica opzionale (interni + federati), **isolata** dalla messaggistica — promesse `SYS-CONTACTS`, `PROM-PERSONAL-CONTACTS`, `SURF-CONTACTS` · ADR `docs/decisions/address-based-messaging.md`
- **Ricezione filtrata**: allow list personale `reception_allowlist` — sempre attiva; lista vuota = nessun recapito; rifiuto silenzioso (✓ singola) — promesse `SYS-RECEPTION`, `PROM-RECEPTION-FILTER`, `SURF-ALLOWLIST`; toggle rapido anche da scheda profilo peer (tap avatar) — promesse `PROM-PEER-PROFILE`, `SURF-PEER-PROFILE`
- **Gruppi**: account `profile_kind = group` con identità propria; partecipazione **solo** allow list bidirezionale (no membership); shell senza inbox; erogazione automatica verso allow list del gruppo; UI autore (avatar + nome) in chat — promessa `SYS-GROUP` (PR #162)
- **Messaggistica per indirizzo**: `username` (Alfred) o `user@server` (esterno, `unsupported` in Alpha); archivio **per owner** in `messages` (`owner_id`, `author_id`, `peer_profile_id`, `original_author_id`); inbox = `list_inbox()` on-read sul mio archivio; chat per `peer_profile_id`
- **Inbox + chat realtime**: Postgres + Realtime; ricerca liste on-demand — inbox, rubrica, persone consentite (`PROM-LIST-FILTER`, PR #132, #171)
- **GIF / voice / location**: bucket `chat-media` per media; posizione statica (lat/lng in Postgres); `OutboundMessageQueue` per retry client
- **Federazione**: outbox `queued` — attende bridge
- **Spunte**: `delivered_at` / `read_at` nullable su copia archivio · `mark_peer_read` aggiorna lettura locale + segnale su copia mittente — promessa `SYS-MAILBOX`
- **Brand**: `#2D2926`, layout responsive stile WhatsApp Web

### Tecnologie

| Categoria | Tecnologia |
|-----------|------------|
| Client | Flutter 3.44.x / Dart 3.12 |
| Piattaforma | Supabase (Postgres, Auth, Realtime, Storage) |
| Bridge | Python 3.12 + aiohttp (Fly.io) |
| CI | GitHub Actions `deploy-alpha` |

---

## 🏗️ Architettura

```
┌─────────────────────────────┐
│   Flutter (client/)         │  ← UI; solo piattaforma
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
- **Dettaglio completo**: `docs/architecture/alpha-full-stack.md`
- **Modello caselle (mailbox)**: `docs/architecture/mailbox-inbox-outbox-spec.md` — archivio per owner + outbox sempre; promessa `SYS-MAILBOX` in `docs/specs/promises/system/` (PR #159)

---

## 📂 Struttura File e Responsabilità

### Root

```
/workspace/
├── client/                 # Client Flutter (fase Alpha — deploy demo su GitHub Pages)
├── supabase/               # Migrazioni e config piattaforma
├── bridge-xmpp/            # Demone bridge XMPP (stub)
├── bridge-matrix/          # Demone bridge Matrix (stub)
├── deploy/                 # Manifest deploy (supabase.json, fly-bridges.json)
├── docs/                   # Documentazione tecnica AI
├── fly.toml, Dockerfile    # Deploy bridge Fly.io
├── PROJECT_MAP.md          # Questo file
└── .cursor-rules.md        # Regole sviluppo AI
```

### Client Flutter (`client/`)

| Elemento | Dettaglio |
|----------|-----------|
| **Entry** | `lib/main.dart` → `AppShell` → `HomeScreen` (sempre shell; overlay auth se 0 account o «Aggiungi account») |
| **State** | Provider: `AuthController` (→ `AccountManager`), `InboxController` per account in focus, `ContactsController`, `MessagesController`, `GroupMessagesController` |
| **Backend** | `SupabaseClient` della sessione in **focus** (una GoTrue attiva) — REST + Realtime + RPC |
| **Config** | `lib/config/app_config.dart` — `--dart-define=SUPABASE_URL` |
| **Gate** | `scripts/verify.sh` — pub get + analyze (zero issue) + test |
| **Build web** | `flutter build web --base-href "/XmppTest/"` |

**Non deducibile — multi-account client**: `AccountManager` / `AccountSession` — manifest `alfred_saved_accounts` elenca **tutti** gli account aperti; in RAM **al massimo una** `AccountSession` GoTrue (quella in focus). Al `setFocus`: dispose sessione corrente (`clearAuthStorage: false`), `AccountSession.restore()` dal manifest, `inboxController.load()`. Storage auth per account: `SharedPreferencesLocalStorage` → `alfred_auth_{userId}`. Persistenza **dichiarativa** per entry (`persistOpenAccount` / `upsertAccount` al login e `tokenRefreshed` — **vietato** `saveAllAccounts` nel runtime). `openAccounts` legge dal manifest. **Vista UI** (`AccountViewState` per `userId`): chat aperta + inbox/chat su mobile **indipendenti per account**. Inbox UI: `HomeScreen` + `ListenableBuilder` su `focusedSession?.inboxController`. Coda invio: `userId|peerProfileId`. Overlay credenziali su `HomeScreen`. Doc: `docs/decisions/multi-account-parallel-sessions.md`, `docs/implementation/multi-account-client.md`, `docs/fixes/multi-account-single-active-gotrue-pr152.md`.

**Non deducibile — auth bootstrap**: login/add-account usa client effimero; **non** chiamare `signOut` sul bootstrap dopo adozione sessione dedicata (revoca refresh GoTrue). PKCE: `EphemeralPkceStorage`. Fix: PR #142 — `docs/fixes/auth-bootstrap-gotrue-revoke.md`. **Chiudi account** = logout **solo locale** (`close()` cancella storage, nessuna `POST /auth/v1/logout`). Fix multi-account PR #143: `docs/fixes/multi-account-chat-persistence-pr143.md`. Handoff: `docs/SESSION_HANDOFF.md`.

**Non deducibile — layout inbox**: `HomeScreen` — mobile drawer `AccountSidebar`; desktop colonna sinistra account + inbox. `AccountSidebar`: chiusura account in card profilo. `InboxPanel`: ricerca on-demand ([PROM-LIST-FILTER](docs/specs/promises/product/PROM-LIST-FILTER.md), [SURF-INBOX](docs/specs/surfaces/SURF-INBOX.md)), `ValueKey(userId)` al cambio focus.

**Non deducibile — chat**: `AnchoredMessageList` (`ListView` reverse, soglia 48 px). Spec: `docs/design/conversation-bottom-anchor.md`.

**Non deducibile — voice**: hold-to-send, WebM/Opus canonico. Spec: `docs/implementation/voice-notes.md`.

**Non deducibile — posizione statica**: tap pin → anteprima mappa OSM (`flutter_map`) con affinamento GPS → conferma invio; bolle ricevute stesso widget tile OSM. Spec: `docs/implementation/location-sharing.md`.

**Non deducibile — profilo pubblico UI**: `ProfileSummary` (`lib/models/profile_summary.dart`) — unico modello per nome, username, avatar, pronomi, `profileKind` (`user`/`group`); usato da `UserProfile.summary`, `OpenAccount.profile`, `ChatPeer.profile`. Promesse: `SYS-PROFILE`, `PROM-PROFILE-IDENTITY`, `SURF-PROFILE`, `SYS-GROUP`. Fetch batch: `ProfileService.fetchSummariesByIds`. Widget condivisi: `ProfileAvatar`, `ProfileIdentityLines` (`lib/widgets/profile_identity.dart`). **Scheda profilo peer**: tap avatar → `showPeerProfileOverlay` (`lib/widgets/peer_profile_overlay.dart`) — Allow + rubrica; promesse `PROM-PEER-PROFILE`, `SURF-PEER-PROFILE`, doc `docs/implementation/peer-profile-overlay.md`.

**Non deducibile — shell gruppo**: focus su account `group` → `HomeScreen` nasconde inbox; `GroupConversationScreen` (storico unico + broadcast); allow list e profilo come account umano; layout mobile full-width sotto 720px. Chat con peer gruppo (account `user`): `MessagesController` con `peerIsGroup` + etichette autore (`MessageAuthorHeader`, `author_display.dart`). Doc: `docs/implementation/groups-client.md`, promessa `SYS-GROUP`.

**Non deducibile — coda invio client**: `OutboundMessageQueue` ≠ outbox server federato.

---

## 🌐 Servizi Esterni

### Supabase (`tvwpoxxcqwphryvuyqzu`, EU)

- Config: `supabase/config.toml`, `supabase/migrations/`, `deploy/supabase.json`
- MCP agente: `execute_sql`, `apply_migration`, `list_migrations`
- **Non deducibile — redirect auth email**: `signUp` / `resetPasswordForEmail` passano `emailRedirectTo`/`redirectTo` da `AuthRedirectUrl.resolve()` (`client/lib/utils/auth_redirect_url.dart`) — su web = origine corrente; default = URL Alpha GitHub Pages (`https://alfred-im.github.io/XmppTest/`, **non produzione**). Dashboard Supabase → Auth → URL Configuration: `site_url` e `uri_allow_list` devono includere lo stesso URL (vedi `supabase/config.toml`).

### Fly.io (`xmpptest`, `fra`)

| Bridge | Health |
|--------|--------|
| XMPP | `https://xmpptest.fly.dev/health` |
| Matrix | `https://xmpptest.fly.dev:8081/health` |

Avvio container: `scripts/start-bridges.sh`.

---

## 💾 Database e Storage

**Fonte di verità messaggistica**: tabella `messages` (archivio per `owner_id`) + `profiles`. Inbox = aggregazione on-read (`list_inbox()` sul mio archivio), nessuna tabella/cache inbox. Invio: outbox sempre → materializzazione copie mittente/destinatario in una RPC.

| Storage | Uso |
|---------|-----|
| Postgres | `profiles` (+ `pronouns`), `contacts`, `reception_allowlist`, `messages`, `outbox`, `sync_cursors`, `bridge_jobs` |
| Storage `chat-media` | GIF + voice WebM (`{userId}/{uuid}.…`) |
| Storage `avatars` | Foto profilo (`{userId}/avatar.{jpg|png|webp}`, max 2 MB) |
| Client `SharedPreferences` | Account aperti (`OpenAccount` + refresh token) e `focusUserId` |

RPC principali: `list_inbox`, `find_profile_by_username`, `send_message_to_profile`, `list_peer_messages`, `list_owner_messages`, `broadcast_message_to_allowlist`, `mark_peer_read`.

Dettaglio schema, RLS, trigger: `docs/architecture/alpha-full-stack.md` §3.

---

## 🔧 Build e Testing

```bash
cd client
bash scripts/verify.sh           # obbligatorio prima di git push
bash scripts/verify.sh --build   # + build web
```

- CI: `.github/workflows/deploy-pages.yml` → `deploy-alpha` → GitHub Pages
- **Vincolo GitHub**: Environment `github-pages` → *Deployment branches: All branches* (deploy da PR)
- E2E: `client/e2e/` (Playwright)
- SQL smoke: `schema_smoke.sql`, `mailbox_*.sql`, `reception_allowlist_*.sql`, `group_schema_smoke.sql`, `group_delivery_smoke.sql`, `group_broadcast_smoke.sql`, `send_message_to_profile_smoke.sql`

---

## 📊 Stato Corrente

### Implementato (Alpha)

| Area | Stato |
|------|-------|
| Auth, profilo, multi-account, scheda profilo peer | ✅ |
| Contatti, inbox, chat testo/GIF/voice/location | ✅ |
| Modello caselle (mailbox per-owner, outbox sempre) | ✅ |
| Account gruppo (shell, erogazione, UI autore) | ✅ |
| Ricerca inbox on-demand, aggancio al fondo | ✅ |
| Schema Supabase + RLS + RPC | ✅ |
| Deploy Pages + gate `verify.sh` | ✅ |
| Bridge federazione | 🟡 Stub health only |

### Prossimi passi

- Bridge XMPP/Matrix (consume `outbox`, `sync_cursors`) — `docs/architecture/alpha-full-stack.md`
- Spunte federate via bridge

### Design system

- Colore: `#2D2926` — `client/lib/theme/alfred_colors.dart`
- Logo: `client/lib/widgets/alfred_logo.dart`

---

## 🔄 Ultima Revisione

**Data**: 2026-07-08

- SDD registro promesse (#171, #172): `docs/specs/registry.md` — SYS/PROM/SURF; epurazione residui doc legacy
- SYS-GROUP (#162): account gruppo, erogazione, broadcast singola riga, `original_author_id`, UI autore avatar+nome; doc hub + `groups-client.md`
- SYS-RECEPTION (#161): allow list ricezione, gate server, UI «Persone consentite»; doc hub + semantica spunte ✓/✓✓
- SYS-MAILBOX (#159): migrazione `20260704120000`, client allineato (`delivered_at`/`read_at`)
- Revisione precedente: sync PR #108–#153; posizione statica (#153); multi-account (#147/#152)
- Revisione doc 2026-07-04: allineamento post-mailbox (#159), contratti promossi, INDICE/README

**Riferimenti**: `docs/INDICE.md`, `docs/architecture/alpha-pr-registry.md`, `CHANGELOG.md`
