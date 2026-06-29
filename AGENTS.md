# AGENTS.md

## Cursor Cloud specific instructions

Alfred is a **Flutter web** messaging client (`client/`) backed by a **live, hosted Supabase**
project. There is no local backend to start: the Supabase URL + anon key are baked into
`client/lib/config/app_config.dart` defaults, so the running web app talks to the real cloud
backend out of the box.

### Toolchain (already provisioned in the VM snapshot)
- Flutter SDK lives at `/opt/flutter` and is on `PATH` via `~/.bashrc` (Flutter 3.44.x / Dart 3.12.x).
- The startup update script only refreshes dependencies (`flutter pub get` + `npm install` in `client/`).
  If `flutter` is not found in a non-interactive shell, call it by absolute path `/opt/flutter/bin/flutter`.

### Lint / test / build
- Standard gate is `cd client && bash scripts/verify.sh` (= `flutter pub get` → `flutter analyze` → `flutter test`). See `scripts/verify.sh` / `README.md`. `flutter analyze` must be zero-issue (even `info`), matching CI.
- Web build: `bash scripts/verify.sh --build` (or `flutter build web --release --base-href "/XmppTest/"`).
- **Prima di qualsiasi test GUI**: `bash scripts/diagnose-test-env.sh` — se fallisce, non usare computerUse (CDP morto = hang).
- **Integrazione multi-account senza browser** (affidabile per agenti): `bash scripts/integration-multi-account.sh` — login agent1/agent2 + RPC inbox/messaggi su Supabase live.

### Running the app (dev)
- `cd client && flutter run -d web-server --web-port=8080 --web-hostname=0.0.0.0`, then open `http://localhost:8080/`.
- Use the `web-server` device (above): `-d chrome` requires `CHROME_EXECUTABLE` + a display and is less reliable here.
- **Non riavviare `flutter run` se la porta 8080 è già in uso** — crea istanze orfane e tmux in errore. Verificare con `diagnose-test-env.sh`; kill mirato del PID su 8080 solo se necessario.

### Deploy Alpha (GitHub Pages)
- **Non** assumere che https://alfred-im.github.io/XmppTest/ rifletta il branch `main`: `deploy-alpha` pubblica da **PR su `main`** e da **push su `main`** (ultimo deploy riuscito vince). Vedi `docs/architecture/alpha-full-stack.md` §6.

### Auth / messaging gotchas (non-obvious, hit during setup)
- Registration: GoTrue rejects unrealistic email domains (e.g. `@example.com` → "Email address is invalid"). Use a realistic domain like `gmail.com`.
- New signups require **email confirmation** before login. For testing, confirm directly in Supabase:
  `update auth.users set email_confirmed_at = now() where email = '<addr>';` (via the Supabase MCP `execute_sql`).
- Supabase enforces an **email send rate limit**; rapid repeated signups fail with "email rate limit exceeded".
- Messaging needs a real recipient profile: **self-messaging fails** ("Utente non trovato") and external `user@server` addresses are **unsupported** in Alpha ("Indirizzo esterno non ancora supportato"). Seeded recipients exist in the live DB (e.g. `test1`, `test2`, `test3`).
- **Account debug agente:** usare **solo** `alfredagent1` / `alfredagent2` (credenziali in `docs/AGENT_DEBUG_ACCOUNTS.md`). **Non modificare mai** password o dati di `test1`/`test2`/`test3` — vedi incidente documentato in quel file (2026-06-29).

### Browser (computerUse) testing of Flutter web
- **Eseguire sempre `bash scripts/diagnose-test-env.sh` prima.** Se Chrome CDP `:9222` non risponde, computerUse si blocca (processo Chrome zombie dopo crash Flutter / schermata rossa).
- **Preferire** `scripts/integration-multi-account.sh` per auth + messaggistica multi-account; Playwright/`verify.sh` per il client Dart.
- **Non** riavviare flutter in loop per "sbloccare" i test GUI — peggiora lo stato (port conflict, CDP morto).
- Inputs are typeable: **click directly into a field to focus it, then type** (don't assume canvas blocks input).
- A brief (~1s) white flash can appear during navigation transitions in the debug web build; it self-resolves and is not a crash.

### Optional e2e (Playwright, in `client/`)
- `npm install` then `npx playwright install chromium`. Tests default to the deployed GitHub Pages URL; override with `ALFRED_BASE_URL` (e.g. `http://localhost:8080/`).
- `e2e/pages-smoke.spec.ts` uses DOM text matching and is unreliable against Flutter's canvas (it does not enable the accessibility tree); `e2e/inbox-load.spec.ts` enables accessibility first. Treat this suite as a best-effort smoke harness.
