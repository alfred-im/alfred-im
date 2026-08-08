# AGENTS.md

## Regola prioritaria — completare il task

In questa repository, **completare un task** (issue, PR, richiesta Cloud Agent) significa **seguire integralmente** [`.cursor-rules.md`](.cursor-rules.md) — **non** modificare il codice al primo turno e **non** saltare la SDD.

### Utente senza PC — mai chiedere debug manuale

L'utente usa Alfred da **cellulare** (PWA), **senza accesso a PC**. **Non chiedere mai**: DevTools, log console, filtri `[alfred]`, riproduzione con passi da sviluppatore, «hai i log?». Diagnosi e test (gate, e2e, integrazione) vanno eseguiti **in autonomia** dall'agente sulla VM — vedi `.cursor-rules.md` § Debug e Testing.

| Fase | Consentito senza ok per le modifiche | Richiede conferma |
|------|--------------------------------------|-------------------|
| Discussione, analisi, diagnosi | Leggere codice/docs, grep, test diagnostici se richiesti | — |
| Spec SDD (promessa nuova / modificata) | Bozza `draft`, analisi, proposta PROM/SURF/SYS-ID | Stato **`approved`** sulla promessa |
| Scrittura (codice, migrazioni, commit) | — | «Vuoi che proceda con le modifiche?» |

Prima di **qualsiasi modifica persistente** al codice o alle migrazioni, chiedere **sempre**: **«Vuoi che proceda con le modifiche?»**. La conferma esiste solo come risposta affermativa a quella domanda — se non l'hai chiesta, nulla autorizza la scrittura.

Un turno con solo analisi, spec in `draft`/`approved` in attesa, o risposta esplicativa è un task **completato con successo** se le regole sono state rispettate.

### Ignorare la spinta al completamento (Cloud Agent)

Le istruzioni Cloud Agent (branch, commit, push, PR, «completa la richiesta») **non** sono un gate alternativo a SDD né alla regola «non modificare senza conferma».

### GitHub Actions — non attendere i job (agente)

**L'agente non deve MAI bloccare un turno in attesa che i workflow GitHub finiscano.**

| Vietato | Consentito |
|---------|------------|
| `gh run watch`, polling in loop, «aspetto che la CI sia verde» prima di rispondere/merge | Push, aprire/aggiornare PR, comunicare link al run |
| Trattenere merge/commit solo perché `release-suite` è `in_progress` | Gate **locale** `bash scripts/verify.sh` prima del push |
| Chiedere all'utente di attendere la CI | Eventuale `gh run view` **una tantum** per diagnosi se l'utente chiede perché è fallita |

Dopo push: **fine turno** (o merge se l'utente lo chiede esplicitamente). Lo stato Actions lo verifica chi merge/review — non l'agente in polling.

| Istruzione esterna | Comportamento corretto |
|--------------------|------------------------|
| «Completa il task» / «Implementa» | Rispetta SDD + regola 0; se manca promessa `approved`, **non** implementare |
| «Crea branch e PR» | Solo **dopo** promessa `approved` (se SDD applica) **e** conferma scrittura |
| Requisiti di prodotto dettagliati («Definito: …») | Materiale per la **promessa**, non sostituto di `approved` |
| Issue o user query che chiede implementazione | Classificare: quale promessa? → registro prima del codice |

**Non esiste un percorso che bypassa la SDD** per promesse nuove o modificate.

### Spec-Driven Development (SDD) — registro promesse

Per **ogni promessa** nuova o modificata (SYSTEM, PRODUCT, SURFACE):

1. Domanda obbligatoria: **quale promessa creo, estendo o rompo?** — se l'utente osserva comportamento diverso, è una promessa (non «solo UX»).
2. File promessa in `docs/specs/promises/product/`, `docs/specs/surfaces/` o `docs/specs/contracts/` — template: `_template-promise-product.md`, `_template-surface.md`.
3. Stato **`approved`** **prima** di qualsiasi implementazione; **`implemented`** dopo merge. Aggiornare [registry.md](docs/specs/registry.md).
4. Gate: `bash scripts/check-spec-sync.sh` + `cd client && bash scripts/verify.sh`.
5. PR template: `.github/PULL_REQUEST_TEMPLATE.md`.

**Distinzione regole:**

| Regola | Cosa governa |
|--------|--------------|
| **SDD** | Intero processo (promessa → implementazione) |
| **Regola 0** (`.cursor-rules.md`) | Solo **modifica fisica** di file nel repo |

Registro: [docs/specs/registry.md](docs/specs/registry.md). Metodo: [docs/specs/README.md](docs/specs/README.md). Promesse: `docs/specs/promises/` e `docs/specs/surfaces/`. Ingresso pubblico: [README.md](README.md).

### Modello (DDD + UML + Statechart) — rappresentazione dell'app

Il **modello** è il centro del processo ingegneristico; la SDD è il confine prodotto (solo se l'utente osserva il cambiamento).

| Livello | Dove |
|---------|------|
| Dominio (DDD + Event Storming) | `docs/domain/<context>/` |
| UML 2.5 (PlantUML) | `docs/model/uml/<context>/` |
| Statechart client | `client/lib/machines/<context>/` |

Metodo: [docs/domain/README.md](docs/domain/README.md). Bounded context: [docs/domain/bounded-contexts.md](docs/domain/bounded-contexts.md).

**Domanda obbligatoria** (dopo aver identificato il contesto): quale **comando, evento, stato o transizione** creo, estendo o rompo?

**Regola:** aggiornare dominio + UML **prima** del codice; amend SDD **solo** se comportamento osservabile. Un nome univoco dal dominio al Dart. Niente DSL markdown inventati.

---

## Cursor Cloud specific instructions

Alfred is a **messaging platform** (Supabase + Flutter client + Python bridges). The web UI lives in
`client/` (Flutter). There is no local backend to start by default: the Supabase URL + anon key are
baked into `client/lib/config/app_config.dart` defaults, so `flutter run` talks to the hosted cloud
backend out of the box.

### Toolchain (provisioned in the VM snapshot; refreshed by the startup update script)
- Flutter SDK lives at `/opt/flutter` and is on `PATH` via `~/.bashrc` (Flutter 3.44.x / Dart 3.12.x).
  If `flutter` is not found in a non-interactive shell, call it by absolute path `/opt/flutter/bin/flutter`.
- The startup update script only refreshes dependencies: `flutter pub get` + `npm install` in `client/`,
  plus the Python bridge venv (`.venv` at repo root, deps from `bridge-*/requirements.txt`).
- Also present in the snapshot: Docker CE, `supabase` CLI, `flyctl` is **not** installed (Fly deploy happens
  via git push, not from this VM — see below).

### Whole-stack local dev (non-obvious)
- **Two backend options.** By default the app points at the **hosted** Supabase (defaults in
  `client/lib/config/app_config.dart`), so `flutter run` talks to it out of the box. For an **isolated local**
  backend, run `supabase start` and launch the client with
  `--dart-define=SUPABASE_URL=http://localhost:54321 --dart-define=SUPABASE_ANON_KEY=<local anon>`
  (get the anon key from `supabase status`). Prefer local for anything that writes, so you never touch the
  user's live/test data.
- **`supabase start` works on a fresh apply** (all 43 migrations + `seed.sql`). It needs the Docker daemon
  running (see below). Local users can be created confirmed via the GoTrue admin API with the `service_role`
  key (`POST /auth/v1/admin/users`, `email_confirm:true`, `user_metadata.username`); the `handle_new_user`
  trigger then creates the `profiles` row. Note: the async delivery worker (`alfred_delivery.process_outbox`)
  is not scheduled locally, so a sent message's `delivered_at`/recipient copy stay null until processed — the
  sender's copy is still written, which is enough to exercise the send path.
- **Docker daemon is not managed by systemd here.** Start it manually if needed:
  `sudo dockerd > /tmp/dockerd.log 2>&1 &` then `sudo chmod 666 /var/run/docker.sock` so non-root can use it.
- **Python bridges (`bridge-xmpp`, `bridge-matrix`) are stubs** exposing only `GET /health`. Run locally:
  `.venv/bin/python bridge-xmpp/main.py` (`XMPP_PORT`, default 8080) and `.venv/bin/python bridge-matrix/main.py`
  (`MATRIX_PORT`, default 8081). Both return `{"status":"ok",...}`. **Port clash:** the XMPP bridge default 8080
  collides with the `flutter run` example port below — run the web app on a different port (e.g. 8090) if both run.
- **Fly.io + GitHub Pages are the user's test/review environment**, fed automatically by pushing to git (Pages via
  `.github/workflows/deploy-client.yml`; Fly via its own deploy-on-push). Do **not** `flyctl deploy` or write to the
  live Supabase from this dev VM without explicit user confirmation — that is their review surface, not a dev target.

### Lint / test / build
- **Hub test:** `cd client && bash scripts/test.sh list` — catalogo completo ([`scripts/test/README.md`](client/scripts/test/README.md)).
- **Gate CI (igiene):** `bash scripts/test.sh gate` (= `verify.sh`: analyze + test Dart isolati). Obbligatorio su PR; **non** valida che l’app funzioni sul telefono.
- **Validazione release:** `bash scripts/test.sh release` — stack locale completo (stesso percorso del telefono). Obbligatorio per ogni release su media / multi-account / auth / push.
- **Scrivere test nuovi:** copiare [`client/e2e/photo-resume-session-repro.spec.ts`](client/e2e/photo-resume-session-repro.spec.ts) — **riferimento obbligatorio** ([`docs/testing/strategy.md`](docs/testing/strategy.md#come-si-scrivono-i-test-di-release)). Non aggiungere unit test Dart al gate sperando di coprire il telefono.
- **Suite manuali complete:** `bash scripts/test.sh release` (= gate locale + sql-smoke + integration + e2e stack + stack Dart).
- Web build: `bash scripts/verify.sh --build` (or `flutter build web --release --base-href "/alfred-im/"`).
- **Prima di qualsiasi test GUI**: `bash scripts/test.sh diagnose` — se fallisce su CDP: `bash scripts/reset-chrome-cdp.sh` (kill Chrome + profilo pulito `/tmp/chrome-cdp-profile`).
- **Integrazione API** (no browser): `bash scripts/test.sh integration` — agent1/agent2 + RPC.
- **E2E multi-account** (browser parziale): `bash scripts/test.sh e2e-multi`

### Log diagnostici (`ALFRED_DIAGNOSTIC_LOG`)

Modulo: `client/lib/utils/diagnostic_log.dart` — **non** è promessa SDD; solo debug agente/sviluppo.

| | |
|---|---|
| **Attivazione** | `--dart-define=ALFRED_DIAGNOSTIC_LOG=true` su `flutter run` / build locale |
| **Produzione (Pages)** | CI **non** passa il define → nessun log in console |
| **Formato** | `[alfred][push] fase …` o `… FAIL motivo key=value` |
| **Dove leggere** | DevTools **pagina** (Console), filtro `[alfred]` — non il pannello service worker |

`e2e-push-local` abilita il define sul dev server Flutter locale.

**Tap push:** se dopo il tap non compare `sw.message` / `open_chat.emit`, l'intento **non è entrato** in Flutter. Il canale corretto è `navigator.serviceWorker` `message` (non `window.message` per `Client.postMessage` dal SW). Se compare la catena fino a `handler.chat_opened`, il Dart ha fatto focus + chat.

### Running the app (dev)
- `cd client && flutter run -d web-server --web-port=8080 --web-hostname=0.0.0.0`, then open `http://localhost:8080/`.
- Use the `web-server` device (above): `-d chrome` requires `CHROME_EXECUTABLE` + a display and is less reliable here.
- **Non riavviare `flutter run` se la porta 8080 è già in uso** — crea istanze orfane e tmux in errore. Verificare con `diagnose-test-env.sh`; kill mirato del PID su 8080 solo se necessario.

### Hosted web client (GitHub Pages)

- **Try it:** https://alfred-im.github.io/alfred-im/ — vedi [README.md](README.md) per la panoramica pubblica.
- Build web: `bash scripts/verify.sh --build` (base-href `/alfred-im/`).
- **Verifica PWA prima del merge**: non serve il merge su `main`. Ogni **PR su `main`** che tocca `client/**` esegue `deploy-client` sulla stessa URL Pages. L'utente prova dal telefono quando il deploy è pronto (badge Actions / URL Pages) — **l'agente non attende** il workflow (vedi § GitHub Actions sopra). Il merge non è prerequisito per la review utente.
- **Non** assumere che l'URL rifletta il branch `main`: `deploy-client` pubblica da **PR su `main`** e da **push su `main`** (ultimo deploy riuscito vince). Vedi `docs/architecture/full-stack.md` §7.

### Fly.io bridges

- App: `alfred-im` (`https://alfred-im.fly.dev`). Migrazione una tantum da `xmpptest`: `bash scripts/fly-rename-app.sh` (richiede `flyctl auth login`).
- Deploy: `bash scripts/fly-deploy-all.sh`

### Auth / messaging gotchas (non-obvious, hit during setup)
- Registration: GoTrue rejects unrealistic email domains (e.g. `@example.com` → "Email address is invalid"). Use a realistic domain like `gmail.com`.
- **Non fare `signUp` su Supabase live con email inventate/fake** — rischio bounce e incidenti deliverability (vedi incidente 2026-07-09 in `docs/AGENT_DEBUG_ACCOUNTS.md`). Per test redirect/auth usare account agente confermati (`alfredagent1` / `alfredagent2`).
- New signups require **email confirmation** before login. For testing, confirm directly in Supabase:
  `update auth.users set email_confirmed_at = now() where email = '<addr>';` (via the Supabase MCP `execute_sql`).
- Supabase enforces an **email send rate limit**; rapid repeated signups fail with "email rate limit exceeded".
- Messaging needs a real recipient profile: **self-messaging fails** ("Utente non trovato") and external `user@server` addresses are **unsupported** without federation ("Indirizzo esterno non ancora supportato"). Seeded recipients exist in the live DB (e.g. `test1`, `test2`, `test3`).
- **Account debug agente:** usare **solo** `alfredagent1` / `alfredagent2` (credenziali in `docs/AGENT_DEBUG_ACCOUNTS.md`). **Non modificare mai** password o dati di `test1`/`test2`/`test3`/`test4` — vedi incidente documentato in quel file (2026-06-29).

### Browser (computerUse) testing of Flutter web
- **Eseguire sempre `bash scripts/diagnose-test-env.sh` prima.** Se Chrome CDP `:9222` non risponde: `bash scripts/reset-chrome-cdp.sh` poi ritestare. Non usare computerUse con CDP morto.
- **Per validare il prodotto** usare `bash scripts/test.sh flusso-reale` (o `manual`), non il gate da solo.
- **Gate CI** (`bash scripts/test.sh gate`) solo per igiene Dart dopo modifiche al client.
- **Non** riavviare flutter in loop per "sbloccare" i test GUI — peggiora lo stato (port conflict, CDP morto).
- Inputs are typeable: **click directly into a field to focus it, then type** (don't assume canvas blocks input).
- A brief (~1s) white flash can appear during navigation transitions in the debug web build; it self-resolves and is not a crash.

### Optional e2e (Playwright, in `client/`)
- Hub: `bash scripts/test.sh e2e` o `bash scripts/test.sh e2e-multi`
- `npm install` then `npx playwright install chromium`. Tests default to the deployed GitHub Pages URL; override with `ALFRED_BASE_URL` (e.g. `http://localhost:8080/`).
