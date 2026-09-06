# Deploy Fly.io — client web (PWA)

**Live (demo istanza):** https://alfred-im-web.fly.dev/

Via canonica per **pubblicare il client** di un'istanza Alfred. Stack container: **nginx** (asset Flutter statici) + **gateway Python** (shell PWA dinamica). I bridge restano sull'app `alfred-im` (root `fly.toml`); il client usa un'**app Fly separata**.

## Configurazione istanza — due strati

Ogni istanza Alfred ha **due livelli** di configurazione. Non sono intercambiabili: il primo è prerequisito del secondo.

```text
config.json (deploy)  →  supabaseUrl + anon key  →  client connesso al backend
                              ↓
                    get_instance_bootstrap (RPC)
                              ↓
              instance_config (Supabase)  →  owner può editare da app
```

### Strato 1 — Cablaggio deploy (`config.json`)

File statico servito da nginx (`/config.json`). Il client lo legge **prima** di qualsiasi RPC (`DeployConfig.load()` in `bootstrapApp()`).

| Campo | Obbligatorio | Ruolo |
|-------|--------------|--------|
| `supabaseUrl` | sì | URL del progetto Supabase di questa istanza |
| `supabaseAnonKey` | sì | Chiave anon (pubblica per design SPA) |
| `publicBaseUrl` | consigliato in produzione | URL pubblico dell'app — vedi sotto |

**Perché non è editabile dall'owner:** senza `supabaseUrl` e `supabaseAnonKey` il client non sa dove connettersi. Il pannello owner (`SURF-INSTANCE-CONFIG`) usa RPC su Supabase (`get_instance_bootstrap`, `upsert_instance_config`) — quindi richiede già una connessione funzionante. Spostare il cablaggio in `instance_config` non elimina il problema: servirebbe comunque un primo hop statico (questo file, env, o redirect) per raggiungere il backend.

Se `config.json` manca o è invalido, l'app mostra `DeployConfigErrorScreen` e non parte.

**Chi lo imposta:** l'operatore che deploya il client (modifica `client/deploy/fly/config.json` prima di `fly deploy`). Non è nel form owner.

Esempio: `client/web/config.json.example`.

### Strato 2 — Config istanza (`instance_config` in Supabase)

Dati dell'istanza letti via RPC `get_instance_bootstrap` dopo il cablaggio. L'owner modifica da app (`SURF-INSTANCE-CONFIG` → `upsert_instance_config`).

| Chiave | Esempio | Ruolo |
|--------|---------|--------|
| `instance.display_name` | `Alfred.im Demo` | Nome servizio in UI |
| `instance.im_server_id` | `arkham.example` | **Dominio federativo** — suffisso IM (`user@arkham.example`), link `#user@server`, in futuro host Gotham (`/.well-known/gotham`) |
| `instance.branding` | oggetto JSON | Logo, colori, shell PWA (upload Storage) |
| `instance.legal` | oggetto JSON | Link privacy, termini, supporto |

Seed opzionale al primo setup: `client/deploy/fly/instance_config.sql`.

**Chi lo imposta:** owner (dopo login). Il deploy può solo pre-seedare valori iniziali via SQL.

---

## Due domini HTTP per istanza

Un'istanza può esporre **due ruoli** su uno o due hostname HTTP. Possono **coincidere** (caso più semplice) o restare **separati**.

| Ruolo | Campo / dove vive | Formato | Uso principale |
|-------|-------------------|---------|----------------|
| **URL pubblico** | `publicBaseUrl` in `config.json` | URL con schema (`https://app.example/`) | Dove l'utente accede al client; redirect Supabase Auth dopo conferma email / reset password (`SURF-AUTH-008`) |
| **Dominio federativo** | `instance.im_server_id` in Supabase | Solo hostname (`im.example`) | Identità IM dell'istanza (`joker@im.example`); federazione Gotham sullo stesso host |

### Caso fuso (un solo hostname)

Stesso hostname per entrambi i ruoli — configurazione valida e comune:

```text
publicBaseUrl   = https://arkham.example/
im_server_id    = arkham.example
```

Il client web e (in futuro) Gotham discovery vivono sullo stesso dominio.

### Caso separato (due hostname)

Anche questo è valido se i ruoli sono espliciti:

```text
publicBaseUrl   = https://app.arkham.example/    ← client, auth redirect
im_server_id    = im.arkham.example                ← @server, Gotham
```

Coordinare DNS, deploy e allowlist Supabase Auth su **entrambi** gli host coinvolti nel flusso utente.

### Cosa non confondere

- **`publicBaseUrl`** non è l'unico «host dell'app» in runtime: la navigazione e i link condivisi usano l'origine del browser (`Uri.base`). In produzione, se l'utente entra sempre dall'URL pubblico, coincidono.
- **`im_server_id`** non è un alias decorativo di `publicBaseUrl`: è l'identità di rete IM. Se diverge dall'URL pubblico, deve essere un host reale (DNS + gateway Gotham quando la federazione sarà attiva), non solo un nome brand.
- **Drift involontario** (es. `publicBaseUrl` su Fly e `im_server_id` su un dominio che non punta da nessuna parte) va evitato coordinando deploy e owner.

---

## Architettura runtime

| Percorso | Servito da | Fonte dati |
|----------|------------|------------|
| `/`, `/index.html`, `/manifest.json` | Gateway Python `:8091` (proxy nginx) | RPC `get_instance_bootstrap` via `config.json` — **nessuna cache RAM** |
| `/main.dart.js`, `/assets/*`, `/icons/*`, … | nginx statico | Build Flutter (`flutter build web --pwa-strategy=none`) — CanvasKit incluso in immagine |
| `/config.json` | nginx statico | `client/deploy/fly/config.json` (wiring Supabase + `publicBaseUrl`) |
| `/push_sw.js` | nginx statico | `client/web/push_sw.js` (icona da payload push, fallback statico) |

Template gateway: `client/deploy/gateway/templates/`. Il build Flutter **non** include `index.html` / `manifest.json` branded (rimossi post-build nel Dockerfile).

## Build web e avvio (performance)

Il Dockerfile Fly usa:

```bash
flutter build web --release --base-href / --pwa-strategy=none
```

| Scelta | Motivo |
|--------|--------|
| **`--pwa-strategy=none`** | Il service worker Flutter 3.44 è deprecato: la build default registrava uno stub che si disinstallava e **ricaricava la pagina** (reload multipli, splash lunga). Push Web usa **`push_sw.js`** registrato dal client Dart — non dipende dal SW Flutter. |
| **CanvasKit in immagine** | Non rimuovere `build/web/canvaskit/`: evita ~7 MB da `gstatic.com` a ogni cold start. Gli asset statici (`main.dart.js`, `canvaskit/*`) hanno cache HTTP `immutable` (1 anno) via nginx. |

### Cosa resta lento anche con cache HTTP

La cache del browser **non salta** parse/compile JS (~3,4 MB `main.dart.js`), init CanvasKit WASM né le RPC Supabase a ogni avvio (`config.json`, `get_instance_bootstrap`, `get_push_vapid_public_key`, restore sessione). La shell HTML (`GET /`) passa dal gateway con `Cache-Control: no-cache` (branding dinamico).

Boot client (dopo deploy): `sessionReady` viene impostato **prima** del caricamento inbox (inbox in background con `showLoadingIndicator: false`).

### Benchmark avvio (Playwright)

Dopo deploy, cronometra cold/warm sulla demo:

```bash
cd client && npx playwright test e2e/demo-live-startup-timing.spec.ts --reporter=line
# override URL:
ALFRED_BASE_URL=https://alfred-im-web.fly.dev/ npx playwright test e2e/demo-live-startup-timing.spec.ts
```

Vedi `client/e2e/demo-live-startup-timing.spec.ts` (metriche: splash hidden, navigazioni, transfer rete).

## Checklist configurazione (istanza)

| Cosa | Dove | Chi |
|------|------|-----|
| Cablaggio Supabase + URL pubblico | `config.json` | Operatore deploy |
| Seed iniziale nome / `im_server_id` | `instance_config.sql` (opzionale) | Operatore deploy |
| Branding, legali, `im_server_id` corrente | Pannello owner in app | Owner |

Vedi [Configurazione istanza — due strati](#configurazione-istanza--due-strati) per il modello completo.

Branding shell/PWA (logo, favicon, colori, manifest) si modifica dal **pannello owner** (`SURF-INSTANCE-CONFIG`) → bucket Storage `instance-branding` + chiave `instance.branding`. **Non** editare file statici branded nel deploy Fly.

La anon key in `config.json` è pubblica per design (SPA); non è un secret runtime.

## Primo deploy

Da **root del repository**:

```bash
# 1. Personalizza client/deploy/fly/config.json

# 2. Crea l'app (una tantum) — cambia il nome in fly.toml se necessario
fly apps create alfred-im-web   # oppure fly launch --config client/deploy/fly/fly.toml --no-deploy

# 3. Deploy (build remoto Fly)
bash scripts/fly-deploy-client.sh
```

## Deploy successivi

```bash
bash scripts/fly-deploy-client.sh
```

**Push su GitHub da solo non deploya Fly.** La CI (`docker-client-fly.yml`) esegue solo smoke build locale. Per pubblicare su Fly serve **`fly deploy`** (manuale) oppure **Auto Deploy** configurato in dashboard (vedi sotto).

## Auto-deploy al push (opzionale, dashboard Fly)

Integrazione **Fly Deployments ↔ GitHub** — non è nel repo; va abilitata una tantum:

1. Dashboard Fly → app `alfred-im-web` → **Deployments** → **Settings**
2. Collega il repository GitHub
3. Abilita **Auto Deploy** sul branch (es. `main`)
4. **Config path:** `client/deploy/fly/fly.toml`
5. **Dockerfile path:** `Dockerfile` (relativo a `client/deploy/fly/`)
6. **Working directory / monorepo root:** `.` (root del repo) — **non** `client/deploy/fly`

Se la working directory è `client/deploy/fly`, Fly cerca `client/deploy/fly/client/deploy/fly/Dockerfile` e il build fallisce.

### Errore `client/deploy/fly/client/deploy/fly/Dockerfile not found`

Imposta working directory **`.`** (root repo) in Fly Deployments → Settings.

## Dopo il deploy client

1. **Supabase** — migrazioni in `supabase/migrations/` sul progetto dell'istanza (MCP, `supabase db push`, dashboard). Per branding owner: `20260830100000_instance_branding_storage.sql` (bucket `instance-branding`).
2. **Edge Function** — redeploy `send-push` se cambia il payload push (`supabase/functions/send-push/`).
3. **Supabase Auth** → Redirect URLs: host di `publicBaseUrl` (es. `https://<tua-app>.fly.dev/**`; demo: `https://alfred-im-web.fly.dev/**`)
4. Verifica: `GET /` contiene shell dinamica (`alfred-boot-splash`, no commento `$FLUTTER_BASE_HREF`); `GET /manifest.json` risponde JSON da bootstrap (non file statico pre-merge).

## Smoke test locale

```bash
bash scripts/docker-smoke-client.sh
```

## Riferimenti

- Gateway: `client/deploy/gateway/`
- Federazione (host `im_server_id`): `docs/architecture/gotham-protocol.md`
- SDD: `docs/specs/surfaces/SURF-INSTANCE-CONFIG.md`, `docs/specs/surfaces/SURF-AUTH.md`, `docs/specs/promises/system/SYS-OWNER.md`
- Bridge Fly: root `fly.toml` + `scripts/fly-deploy-all.sh`
- [Fly static sites](https://fly.io/docs/languages-and-frameworks/static/)
