# Alfred — Architettura (panoramica)

**Data**: 2026-09-03  
**Scope**: App completa **senza bridge** (XMPP/Matrix restano stub Fly.io)  
**Stato**: prodotto stabile su `main`

> **SSOT:** [SSOT.md](../SSOT.md) — panoramica stack; non duplica catalogo promesse, RPC né flussi delivery.

> **Contratti (SDD)**: [docs/specs/registry.md](../specs/registry.md)

---

## 1. Panoramica sistema

```
┌─────────────────────────────────────────────────────────────┐
│  Flutter web (`client/`) — PWA                            │
│  Auth · Contatti · Persone consentite · Conversazioni · Chat · Profilo · Multi-account · Gruppi · Link `#` │
└───────────────────────────┬─────────────────────────────────┘
                            │ HTTPS (REST + Realtime + Auth)
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Supabase — Piattaforma Alfred                               │
│  Postgres · RLS · RPC · Realtime · GoTrue                    │
└───────────────────────────┬─────────────────────────────────┘
                            │ (futuro: service_role)
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Bridge XMPP / Matrix — **FUORI SCOPE** (stub health only)   │
└─────────────────────────────────────────────────────────────┘
```

### ADR vincolanti

| ADR | Scelta |
|-----|--------|
| [address-based-messaging](../decisions/address-based-messaging.md) | Messaggistica per indirizzo; rubrica isolata |
| [bridge-stateless](../decisions/bridge-stateless.md) | Stato bridge in piattaforma (`outbox`, `sync_cursors`, `bridge_jobs`) |
| [no-internal-external-chat-distinction](../decisions/no-internal-external-chat-distinction.md) | Protocollo **mai** visibile in UI contatti/inbox |
| [multi-account-parallel-sessions](../decisions/multi-account-parallel-sessions.md) | Multi-account — manifest + focus; una GoTrue attiva |
| [server-as-reception](../decisions/server-as-reception.md) | Ricezione filtrata (allow list) |
| [single-device-logout-open](../decisions/single-device-logout-open.md) | Logout = chiusura locale account (no `signOut` globale) |

---

## 2. Client Flutter — struttura e bootstrap

### 2.1 Directory

```
client/lib/
├── config/       # Supabase URL, chiavi
├── models/       # DTO UI ↔ JSON
├── services/     # Thin API layer
├── providers/    # ChangeNotifier (stato UI)
├── machines/     # Statechart per contesto (auth, messaging, push, …)
├── coordinators/ # Wiring macchine ↔ UI / servizi
├── screens/      # Shell, auth, home, contatti, profilo
├── widgets/      # Componenti presentazionali
└── utils/        # Formattazione, scroll anchor, filtri, shareable link
```

### 2.2 Provider

- `ChangeNotifierProxyProvider` per contatti, profilo e allow list al cambio focus
- Inbox: `ListenableBuilder` su `focusedSession?.inboxController`
- Dettaglio: [guides/multi-account.md](../guides/multi-account.md)

### 2.3 Bootstrap

1. `bootstrapApp()` — solo `WidgetsFlutterBinding`; config istanza (RPC parallele)
2. `AuthController.initialize()`:
   - manifest + focus (`MultiAccountAdapters.bootstrapManifest`)
   - restore sessione focus (`switchToAccount` con `deferInboxLoad: true`)
   - `completeBootstrap()` → `sessionReady` (shell visibile)
   - inbox in background (`refreshFocusedInboxSilently`)
3. `AppShell` → sempre `HomeScreen`; overlay se 0 account
4. Splash HTML (`#alfred-boot-splash` in `client/web/index.html`) si nasconde su evento `flutter-first-frame`
5. `ShareableLinkListener` → fragment `#` in ingresso ([PROM-SHAREABLE-LINK](../specs/promises/product/PROM-SHAREABLE-LINK.md))

**Build web / cold start (Fly):** `--pwa-strategy=none` (no service worker Flutter deprecato), CanvasKit servito dall'origine — dettaglio e benchmark in `client/deploy/fly/README.md` § Build web e avvio.

### 2.4 Link condivisibili (fragment `#`)

Dettaglio: [guides/shareable-link.md](../guides/shareable-link.md).

---

## 3. Promesse e guide

**SSOT catalogo:** [specs/registry.md](../specs/registry.md) · **SSOT guide operative:** [guides/README.md](../guides/README.md)

Non mantenere qui tabelle promessa duplicate — aggiornare solo il registry e i file `PROM-*` / `SURF-*` / `SYS-*`.

---

## 4. Piattaforma Supabase

Schema, enum, RLS, storage: **[contracts/schema.md](../specs/contracts/schema.md)**  
RPC business logic: **[contracts/rpc.md](../specs/contracts/rpc.md)**  
Migrazioni: [`supabase/migrations/`](../../supabase/migrations/)

### Integrazione bridge (non implementata)

Flusso delivery e gate allow list: **SSOT** [mailbox-inbox-outbox-spec.md](./mailbox-inbox-outbox-spec.md) § Consegna. Bridge stateless: [bridge-stateless.md](../decisions/bridge-stateless.md).

---

## 5. Sicurezza

- Password solo GoTrue; RLS su tabelle dominio
- Publishable key nel client (SPA standard)
- `outbox`, `bridge_jobs`, `sync_cursors`: inaccessibili a `authenticated`

---

## 6. Testing

**SSOT:** [testing/strategy.md](../testing/strategy.md) · [client/scripts/test/README.md](../../client/scripts/test/README.md)

Tracciabilità requisiti → test: tabella **Tracciabilità** in ogni promessa (`registry.md`).

---

## 7. Deploy

| Target | Meccanismo |
|--------|------------|
| Web client (Fly.io) | `client/deploy/fly/` + gateway `client/deploy/gateway/` — app `alfred-im-web` — https://alfred-im-web.fly.dev/ |
| Supabase | Migrazioni in repo → MCP / `supabase db push` / dashboard (non automatiche al merge Git) |

**Try it:** https://alfred-im-web.fly.dev/ — panoramica pubblica in [`README.md`](../../README.md).

**Deploy client Fly:** `bash scripts/fly-deploy-client.sh`. Push su GitHub **non** deploya Fly; CI (`docker-client-fly.yml`) = smoke build. Auto-deploy Fly **solo** se abilitato in dashboard (Deployments → GitHub, working dir `.`). Vedi `client/deploy/fly/README.md`.

**White label shell:** `index.html` + `manifest.json` generati dal gateway a ogni GET da `get_instance_bootstrap`; branding owner in `instance.branding` + bucket `instance-branding` (`SURF-INSTANCE-CONFIG`).

**Web**: `passkeys` `bundle.js` obbligatorio in `client/web/index.html` (PR #110).

Dettaglio deploy: `PROJECT_MAP.md` § Build, `client/deploy/fly/README.md`.

---

## 8. Limitazioni attuali (senza bridge)

| Funzionalità | Stato |
|--------------|-------|
| Chat Alfred stessa istanza | ✅ testo, GIF, voice, location, image, video (recapito solo se mittente ∈ allow list destinatario) |
| Chat gruppo Alfred | ✅ account gruppo, erogazione automatica, broadcast, UI autore (PR #162) |
| Allow list ricezione | ✅ sempre attiva; lista vuota = nessun recapito; UI «Persone consentite» + toggle in scheda profilo peer |
| Link condivisibili | ✅ `#username` / `#username/chat`; share da profilo peer e sidebar (#178) |
| Reazioni emoji | ✅ tap messaggio → picker; `apply_message_reaction` + realtime fatti — [PROM-MESSAGE-REACTIONS](../specs/promises/product/PROM-MESSAGE-REACTIONS.md) |
| @mentions | ✅ `@username` cliccabile in body — [PROM-MESSAGE-MENTION](../specs/promises/product/PROM-MESSAGE-MENTION.md) |
| Rubrica XMPP/Matrix | ✅ salvataggio |
| Invio federato | ⏸ outbox `queued` |
| Ricezione federata | ❌ bridge |
| Push Web (VAPID) | ✅ `implemented` — migrazione + client + Edge Function `send-push` |
| E2EE | ❌ fuori scope |

---

## 9. Prossimi passi (post-bridge)

1. Worker bridge: claim `outbox`
2. Ingestione inbound → copie archivio destinatario + Realtime
3. Spunte XEP-0184/0333 via bridge

---

**Riferimenti**: [`README.md`](../../README.md), `PROJECT_MAP.md`, [docs/specs/registry.md](../specs/registry.md), [docs/specs/README.md](../specs/README.md)
