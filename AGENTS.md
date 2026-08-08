# AGENTS.md

**SSOT documentazione:** [docs/SSOT.md](docs/SSOT.md) — questo file copre **solo** toolchain Cloud Agent e gotchas VM; non duplica promesse, RPC, test completi né account debug.

Processo agente (regola 0, SDD, modello): [.cursor-rules.md](.cursor-rules.md)

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

**SSOT:** [docs/testing/strategy.md](docs/testing/strategy.md) (gate vs release) · [client/scripts/test/README.md](client/scripts/test/README.md) (catalogo comandi).

- Hub: `cd client && bash scripts/test.sh list`
- Gate: `cd client && bash scripts/test.sh gate` (= `verify.sh`) — obbligatorio su PR; **non** valida il telefono
- Release: `cd client && bash scripts/test.sh release` (alias `manual`, `ci`) — stack locale completo
- Riferimento test release: [`client/e2e/photo-resume-session-repro.spec.ts`](client/e2e/photo-resume-session-repro.spec.ts) — vedi strategy § Come si scrivono i test di release
- Web build: `cd client && bash scripts/verify.sh --build`
- Prima di test GUI: `cd client && bash scripts/test.sh diagnose` — CDP morto → `cd client && bash scripts/reset-chrome-cdp.sh`

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
- **Non riavviare `flutter run` se la porta 8080 è già in uso** — crea istanze orfane e tmux in errore. Verificare con `cd client && bash scripts/diagnose-test-env.sh`; kill mirato del PID su 8080 solo se necessario.

### Hosted web client (GitHub Pages)

- **Try it:** https://alfred-im.github.io/alfred-im/ — vedi [README.md](README.md) per la panoramica pubblica.
- Build web: `cd client && bash scripts/verify.sh --build` (base-href `/alfred-im/`).
- **Verifica PWA prima del merge**: non serve il merge su `main`. Ogni **PR su `main`** che tocca `client/**` esegue `deploy-client` sulla stessa URL Pages. L'utente prova dal telefono quando il deploy è pronto (badge Actions / URL Pages) — **l'agente non attende** il workflow (vedi `.cursor-rules.md`). Il merge non è prerequisito per la review utente.
- **Non** assumere che l'URL rifletta il branch `main`: `deploy-client` pubblica da **PR su `main`** e da **push su `main`** (ultimo deploy riuscito vince). Vedi `docs/architecture/full-stack.md` §7.

### Fly.io bridges

- App: `alfred-im` (`https://alfred-im.fly.dev`). Migrazione una tantum da `xmpptest`: `bash scripts/fly-rename-app.sh` (richiede `flyctl auth login`).
- Deploy: `bash scripts/fly-deploy-all.sh`

### Auth / messaging gotchas (non-obvious, hit during setup)
- Registration: GoTrue rejects unrealistic email domains (e.g. `@example.com` → "Email address is invalid"). Use a realistic domain like `gmail.com`.
- **Non fare `signUp` su Supabase live con email inventate/fake** — vedi [docs/AGENT_DEBUG_ACCOUNTS.md](docs/AGENT_DEBUG_ACCOUNTS.md).
- New signups require **email confirmation** before login. For testing, confirm directly in Supabase:
  `update auth.users set email_confirmed_at = now() where email = '<addr>';` (via the Supabase MCP `execute_sql`).
- Supabase enforces an **email send rate limit**; rapid repeated signups fail with "email rate limit exceeded".
- Messaging needs a real recipient profile: **self-messaging fails** ("Utente non trovato") and external `user@server` addresses are **unsupported** without federation ("Indirizzo esterno non ancora supportato"). Seeded recipients exist in the live DB (e.g. `test1`, `test2`, `test3`).
- **Account debug / test:** regole e percorso locale — **solo** [docs/AGENT_DEBUG_ACCOUNTS.md](docs/AGENT_DEBUG_ACCOUNTS.md) (non duplicare qui).

### Browser (computerUse) testing of Flutter web
- **Eseguire sempre `cd client && bash scripts/diagnose-test-env.sh` prima.** Se Chrome CDP `:9222` non risponde: `cd client && bash scripts/reset-chrome-cdp.sh` poi ritestare. Non usare computerUse con CDP morto.
- **Per validare il prodotto** usare `cd client && bash scripts/test.sh flusso-reale` (o `manual`), non il gate da solo.
- **Gate CI** (`cd client && bash scripts/test.sh gate`) solo per igiene Dart dopo modifiche al client.
- **Non** riavviare flutter in loop per "sbloccare" i test GUI — peggiora lo stato (port conflict, CDP morto).
- Inputs are typeable: **click directly into a field to focus it, then type** (don't assume canvas blocks input).
- A brief (~1s) white flash can appear during navigation transitions in the debug web build; it self-resolves and is not a crash.

### Optional e2e (Playwright, in `client/`)
- Hub: `cd client && bash scripts/test.sh e2e` o `cd client && bash scripts/test.sh e2e-multi`
- `npm install` then `npx playwright install chromium`. Tests default to the deployed GitHub Pages URL; override with `ALFRED_BASE_URL` (e.g. `http://localhost:8080/`).
