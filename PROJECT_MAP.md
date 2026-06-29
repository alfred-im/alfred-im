# Alfred - Mappa Completa del Progetto

**Ultimo aggiornamento**: 2026-06-29 (logout locale + fix chat vuota)  
**Versione repository**: 3.1.0-alpha (client Flutter + piattaforma Supabase; bridge stub)

---

## 📋 Indice

1. [Stato repository](#-stato-repository-2026-06-28)
2. [Panoramica](#-panoramica-progetto)
3. [Architettura](#️-architettura)
4. [Struttura e responsabilità](#-struttura-file-e-responsabilità)
5. [Servizi esterni](#-servizi-esterni)
6. [Database e storage](#-database-e-storage)
7. [Build e testing](#-build-e-testing)
8. [Stato corrente](#-stato-corrente)

> Codice del client React storico: **non su `main`**. Recupero solo via tag git `legacy/web-client-final` — non documentato in questo repository.

---

## ⚠️ Stato repository (2026-06-28)

| Elemento | Dettaglio |
|----------|-----------|
| **Client** | `client/` — Flutter, collegato a Supabase |
| **URL live** | https://alfred-im.github.io/XmppTest/ |
| **Deploy** | `.github/workflows/deploy-pages.yml` — `verify.sh` + build; job `deploy-alpha` (**PR su `main` e push su `main`**, path `client/**`) |

**Non deducibile — URL Alpha ≠ branch `main`**: https://alfred-im.github.io/XmppTest/ pubblica l’**ultimo** `deploy-alpha` riuscito (PR o push). **Non** è vero che «il sito live builda sempre da `main`». Per sapere quale codice è live, controllare quale workflow/PR ha deployato per ultimo (`concurrency: pages-alpha` → ultimo vince).
| **Piattaforma** | Supabase `tvwpoxxcqwphryvuyqzu` — schema dominio + RLS + RPC |
| **Bridge** | `bridge-xmpp/` · `bridge-matrix/` — stub health Fly.io (federazione non implementata) |
| **PR Alpha** | **#108–#132** mergiate su `main` — **#140** draft (multi-account parallelo) — `docs/architecture/alpha-pr-registry.md` |

**Stack su `main`**: `client/` · `supabase/` · `bridge-xmpp/` · `bridge-matrix/`

---

## 📌 Panoramica Progetto

**Alfred** è una piattaforma di messaggistica: **Flutter + Supabase + bridge Python** (federazione futura).

### Caratteristiche attuali

- **Auth**: email + password (GoTrue); **username** obbligatorio in registrazione — identità IM pubblica; email non in rubrica/ricerca
- **Multi-account**: N sessioni Supabase parallele (`AccountManager` + `AccountSession`); account aperto = autenticato + realtime inbox; **focus** = solo UI — ADR `docs/decisions/multi-account-parallel-sessions.md`
- **Contatti**: rubrica opzionale (interni + federati), **isolata** dalla messaggistica — ADR `docs/decisions/address-based-messaging.md`
- **Messaggistica per indirizzo**: `username` (Alfred) o `user@server` (esterno, `unsupported` in Alpha); solo `messages` + `profiles`; inbox = `list_inbox()` on-read; chat per `peer_profile_id`
- **Inbox + chat realtime**: Postgres + Realtime; ricerca conversazioni on-demand (PR #132)
- **GIF / voice**: bucket `chat-media`; `OutboundMessageQueue` per retry client
- **Federazione**: outbox `queued` — attende bridge
- **Spunte**: `delivered` su insert server · `mark_peer_read` → `read` — `docs/decisions/server-as-reception.md`
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
- **Target caselle** (direzione confermata, non su `main`): `docs/architecture/mailbox-inbox-outbox-spec.md` — archivio per owner + outbox sempre; sostituirà ADR message-centric a implementazione

---

## 📂 Struttura File e Responsabilità

### Root

```
/workspace/
├── client/                 # Client Flutter (produzione Alpha)
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
| **State** | Provider: `AuthController` (→ `AccountManager`), `InboxController` per account in focus, `ContactsController`, `MessagesController` |
| **Backend** | N × `SupabaseClient` (uno per account aperto) — REST + Realtime + RPC |
| **Config** | `lib/config/app_config.dart` — `--dart-define=SUPABASE_URL` |
| **Gate** | `scripts/verify.sh` — pub get + analyze (zero issue) + test |
| **Build web** | `flutter build web --base-href "/XmppTest/"` |

**Non deducibile — multi-account client**: `AccountManager` / `AccountSession` — ogni account aperto ha client Supabase dedicato (`SharedPreferencesLocalStorage` per `userId`), `InboxController` sempre attivo con realtime (**lifecycle in `AccountSession.close()`**, non dispose Provider al cambio focus). Lista `OpenAccount` in storage = account autenticati (non bookmark); persistenza **atomica** (`saveAllAccounts` da tutte le sessioni aperte, write serializzate). Switch = `setFocus` senza `setSession`. **Vista UI** (`AccountViewState` per `userId` in `AccountManager`): chat aperta + inbox/chat su mobile **indipendenti per account**; rimosse su chiusura account; sanitizzate se il peer coincide con l'account in focus. Coda invio: chiave `userId|peerProfileId`. Overlay credenziali semi-trasparente su `HomeScreen`. Doc: `docs/decisions/multi-account-parallel-sessions.md`, `docs/design/auth-overlay-shell.md`, `docs/implementation/multi-account-client.md`.

**Non deducibile — auth bootstrap**: login/add-account usa client effimero; **non** chiamare `signOut` sul bootstrap dopo adozione sessione dedicata (revoca refresh GoTrue). PKCE: `EphemeralPkceStorage`. Fix: PR #142 — `docs/fixes/auth-bootstrap-gotrue-revoke.md`. **Chiudi account** = logout **solo locale** (`close()` cancella storage, nessuna `POST /auth/v1/logout`). Handoff: `docs/SESSION_HANDOFF.md`.

**Non deducibile — layout inbox**: `HomeScreen` — mobile drawer `AccountSidebar`; desktop colonna sinistra account + inbox. `AccountSidebar`: chiusura account in card profilo. `InboxPanel`: ricerca on-demand, `ValueKey(userId)` al cambio focus. Spec: `docs/design/inbox-search-toggle.md`.

**Non deducibile — chat**: `AnchoredMessageList` (`ListView` reverse, soglia 48 px). Spec: `docs/design/conversation-bottom-anchor.md`.

**Non deducibile — voice**: hold-to-send, WebM/Opus canonico. Spec: `docs/implementation/voice-notes.md`.

**Non deducibile — profilo pubblico UI**: `ProfileSummary` (`lib/models/profile_summary.dart`) — unico modello per nome, username, avatar, pronomi; usato da `UserProfile.summary`, `OpenAccount.profile`, `ChatPeer.profile`. Fetch batch: `ProfileService.fetchSummariesByIds`. Widget condivisi: `ProfileAvatar`, `ProfileIdentityLines` (`lib/widgets/profile_identity.dart`).

**Non deducibile — coda invio client**: `OutboundMessageQueue` ≠ outbox server federato.

---

## 🌐 Servizi Esterni

### Supabase (`tvwpoxxcqwphryvuyqzu`, EU)

- Config: `supabase/config.toml`, `supabase/migrations/`, `deploy/supabase.json`
- MCP agente: `execute_sql`, `apply_migration`, `list_migrations`
- **Non deducibile — redirect auth email**: `signUp` / `resetPasswordForEmail` passano `emailRedirectTo`/`redirectTo` da `AuthRedirectUrl.resolve()` (`client/lib/utils/auth_redirect_url.dart`) — su web = origine corrente; default produzione `https://alfred-im.github.io/XmppTest/`. Dashboard Supabase → Auth → URL Configuration: `site_url` e `uri_allow_list` devono includere lo stesso URL (vedi `supabase/config.toml`).

### Fly.io (`xmpptest`, `fra`)

| Bridge | Health |
|--------|--------|
| XMPP | `https://xmpptest.fly.dev/health` |
| Matrix | `https://xmpptest.fly.dev:8081/health` |

Avvio container: `scripts/start-bridges.sh`.

---

## 💾 Database e Storage

**Fonte di verità messaggistica**: tabella `messages` + `profiles`. Inbox = aggregazione on-read (`list_inbox()`), nessuna tabella/cache inbox.

| Storage | Uso |
|---------|-----|
| Postgres | `profiles` (+ `pronouns`), `contacts`, `messages`, `outbox`, `sync_cursors`, `bridge_jobs` |
| Storage `chat-media` | GIF + voice WebM (`{userId}/{uuid}.…`) |
| Storage `avatars` | Foto profilo (`{userId}/avatar.{jpg|png|webp}`, max 2 MB) |
| Client `SharedPreferences` | Account aperti (`OpenAccount` + refresh token) e `focusUserId` |

RPC principali: `list_inbox`, `find_profile_by_username`, `send_message_to_profile`, `list_peer_messages`, `mark_peer_read`.

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
- SQL smoke: `supabase/tests/schema_smoke.sql`

---

## 📊 Stato Corrente

### Implementato (Alpha)

| Area | Stato |
|------|-------|
| Auth, profilo, multi-account | ✅ |
| Contatti, inbox, chat testo/GIF/voice | ✅ |
| Ricerca inbox on-demand, aggancio al fondo | ✅ |
| Schema Supabase + RLS + RPC | ✅ |
| Deploy Pages + gate `verify.sh` | ✅ |
| Bridge federazione | 🟡 Stub health only |

### Prossimi passi

- Bridge XMPP/Matrix (consume `outbox`, `sync_cursors`)
- Spunte federate via bridge
- Vedi `docs/decisions/project-revolution-discovery.md`

### Design system

- Colore: `#2D2926` — `client/lib/theme/alfred_colors.dart`
- Logo: `client/lib/widgets/alfred_logo.dart`

---

## 🔄 Ultima Revisione

**Data**: 2026-06-29

- Multi-account: sessioni parallele (`AccountManager`); shell + overlay auth; doc ADR + design + implementation
- Redirect conferma email auth (`AuthRedirectUrl`)

**Riferimenti**: `docs/INDICE.md`, `docs/architecture/alpha-pr-registry.md`, `CHANGELOG.md`
