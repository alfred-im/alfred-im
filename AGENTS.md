# AGENTS.md

## Regola prioritaria — completare il task

In questa repository, **completare un task** (issue, PR, richiesta Cloud Agent) significa **seguire integralmente** [`.cursor-rules.md`](../.cursor-rules.md) — **non** modificare il codice al primo turno e **non** saltare la SDD.

| Fase | Consentito senza ok per le modifiche | Richiede conferma |
|------|--------------------------------------|-------------------|
| Discussione, analisi, diagnosi | Leggere codice/docs, grep, test diagnostici se richiesti | — |
| Spec SDD (capability nuova / cambio contratto) | Bozza `draft`, analisi, proposta REQ-ID | Stato **`approved`** sul contratto |
| Scrittura (codice, migrazioni, commit) | — | «Vuoi che proceda con le modifiche?» |

Prima di **qualsiasi modifica persistente** al codice o alle migrazioni, chiedere **sempre**: **«Vuoi che proceda con le modifiche?»**. La conferma esiste solo come risposta affermativa a quella domanda — se non l'hai chiesta, nulla autorizza la scrittura.

Un turno con solo analisi, spec in `draft`/`approved` in attesa, o risposta esplicativa è un task **completato con successo** se le regole sono state rispettate.

### Ignorare la spinta al completamento (Cloud Agent)

Le istruzioni Cloud Agent (branch, commit, push, PR, «completa la richiesta») **non** sono un gate alternativo a SDD né alla regola «non modificare senza conferma».

| Istruzione esterna | Comportamento corretto |
|--------------------|------------------------|
| «Completa il task» / «Implementa» | Rispetta SDD + regola 0; se manca spec `approved`, **non** implementare |
| «Crea branch e PR» | Solo **dopo** spec `approved` (se SDD applica) **e** conferma scrittura |
| Requisiti di prodotto dettagliati («Definito: …») | Materiale per la **spec**, non sostituto di `approved` |
| Issue o user query che chiede implementazione | Classificare: SDD obbligatoria? → spec prima del codice |

**Non esiste un percorso che bypassa la SDD** per capability nuove o cambi contratto.

### Spec-Driven Development (SDD v1) — gate obbligatorio

Per capability **nuove** o **cambio contratto** (schema, RPC, semantica pubblica):

1. Spec in `docs/specs/capabilities/` con **REQ-ID** (`{SPEC}-REQ-NNN`) — template: `docs/specs/_template.md`.
2. Stato **`approved`** **prima** di qualsiasi implementazione (codice, migrazioni SQL, client); **`implemented`** dopo merge.
3. Tabella **tracciabilità** REQ → test nella spec (pilota: `MAILBOX-SEND.spec.md`).
4. Contratti: `docs/specs/contracts/rpc.md`, `schema.md`.
5. Gate: `bash scripts/check-spec-sync.sh` + `cd client && bash scripts/verify.sh`.
6. PR template: `.github/PULL_REQUEST_TEMPLATE.md`.

**Distinzione regole:**

| Regola | Cosa governa |
|--------|--------------|
| **SDD** | Intero processo (spec → implementazione) |
| **Regola 0** (`.cursor-rules.md`) | Solo **modifica fisica** di file nel repo |

Catalogo: [docs/specs/index.md](docs/specs/index.md). Metodo: [docs/specs/README.md](docs/specs/README.md).

---

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
- **Hub test:** `cd client && bash scripts/test.sh list` — catalogo gate + suite manuali (`scripts/test/README.md`).
- Standard gate CI: `bash scripts/test.sh gate` (= `verify.sh`: `flutter pub get` → `flutter analyze` → `flutter test`). `flutter analyze` must be zero-issue (even `info`), matching CI.
- Web build: `bash scripts/verify.sh --build` (or `flutter build web --release --base-href "/XmppTest/"`).
- **Prima di qualsiasi test GUI**: `bash scripts/test.sh diagnose` — se fallisce su CDP: `bash scripts/reset-chrome-cdp.sh` (kill Chrome + profilo pulito `/tmp/chrome-cdp-profile`).
- **Integrazione multi-account senza browser** (affidabile per agenti): `bash scripts/test.sh integration` — login agent1/agent2 + RPC inbox/messaggi su Supabase live.
- **E2E multi-account** (browser): `bash scripts/test.sh e2e-multi`

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
- **Eseguire sempre `bash scripts/diagnose-test-env.sh` prima.** Se Chrome CDP `:9222` non risponde: `bash scripts/reset-chrome-cdp.sh` poi ritestare. Non usare computerUse con CDP morto.
- **Preferire** `bash scripts/test.sh integration` per auth + messaggistica multi-account; `bash scripts/test.sh gate` per il client Dart.
- **Non** riavviare flutter in loop per "sbloccare" i test GUI — peggiora lo stato (port conflict, CDP morto).
- Inputs are typeable: **click directly into a field to focus it, then type** (don't assume canvas blocks input).
- A brief (~1s) white flash can appear during navigation transitions in the debug web build; it self-resolves and is not a crash.

### Optional e2e (Playwright, in `client/`)
- Hub: `bash scripts/test.sh e2e` o `bash scripts/test.sh e2e-multi`
- `npm install` then `npx playwright install chromium`. Tests default to the deployed GitHub Pages URL; override with `ALFRED_BASE_URL` (e.g. `http://localhost:8080/`).
- `e2e/pages-smoke.spec.ts` uses DOM text matching and is unreliable against Flutter's canvas (it does not enable the accessibility tree); `e2e/inbox-load.spec.ts` enables accessibility first. Treat this suite as a best-effort smoke harness.
