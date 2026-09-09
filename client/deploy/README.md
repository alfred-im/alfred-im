# Deploy Fly.io — client web (PWA)

Via canonica per **pubblicare il client** di un'istanza Alfred. Stack container: **nginx** (asset Flutter statici) + **gateway Python** (shell PWA dinamica). Ogni istanza ha un'**app Fly separata** dal progetto Supabase.

## Istanze demo

| Istanza | URL | Supabase | Directory | Deploy |
|---------|-----|----------|-----------|--------|
| **Arkham** | https://arkham-im.fly.dev/ | `tvwpoxxcqwphryvuyqzu` | `client/deploy/arkham/` | `bash scripts/fly-deploy-client.sh` |
| **Blackgate** | https://blackgate-im.fly.dev/ | `jgxkimvjmlfjdtzsuijh` | `client/deploy/blackgate/` | `bash scripts/fly-deploy-blackgate.sh` |

Asset condivisi (Dockerfile, nginx, entrypoint): `client/deploy/shared/`. Shell gateway Python (branding PWA, **non** gateway Gotham): `client/deploy/gateway/`.

Ogni istanza ha gli stessi file: `fly.toml`, `config.json`, `instance_config.sql`.

## Come si configura un'istanza

Ci sono **due passaggi**, in ordine. Il secondo funziona solo se il primo è a posto.

```text
1. Al deploy: config.json          → il client sa dove sta Supabase
2. Dopo la connessione: Supabase   → nome, logo, dominio IM, ecc. (anche da pannello owner)
```

### Passo 1 — File al deploy (`config.json`)

È un file JSON servito dall'app (`/config.json`). Il browser lo scarica **prima** di parlare con Supabase.

| Campo | Serve? | A cosa serve |
|-------|--------|--------------|
| `supabaseUrl` | obbligatorio | Indirizzo del progetto Supabase di questa istanza |
| `supabaseAnonKey` | obbligatorio | Chiave per connettersi (è pubblica, va bene così per una web app) |
| `publicBaseUrl` | sì in produzione | Indirizzo pubblico dell'app — vedi [Due indirizzi web](#due-indirizzi-web-per-istanza) |

**Perché l'owner non lo cambia dall'app:** per aprire il pannello impostazioni devi già essere connesso a Supabase. Ma per connetterti serve `config.json`. Chiudere questo cerchio dall'interno dell'app non è possibile: qualcosa va scritto **una volta** al deploy.

Se il file manca o è sbagliato, l'app si ferma con «Configurazione mancante».

**Chi lo scrive:** chi fa il deploy (modifica `client/deploy/<istanza>/config.json`, poi deploy). Modello: `client/web/config.json.example`.

### Passo 2 — Dati in Supabase (`instance_config`)

Dopo la connessione, il client legge e (se sei owner) modifica questi dati tramite RPC.

| Chiave | Esempio | A cosa serve |
|--------|---------|--------------|
| `instance.display_name` | `Arkham.im` | Nome del servizio in app — **solo DB** (owner panel o SQL); non è nel build Docker |
| `instance.im_server_id` | `arkham-im.fly.dev` | **Dominio federativo** — parte dopo la `@` negli indirizzi (`mario@arkham-im.fly.dev`) |
| `instance.branding` | oggetto JSON | Logo, colori, titolo browser |
| `instance.legal` | oggetto JSON | Link privacy, termini, supporto |

Valori iniziali opzionali: `client/deploy/<istanza>/instance_config.sql`.

**Chi li scrive:** l'owner dall'app, dopo il login. Il deploy può solo impostare un primo valore con lo script SQL.

---

## Due indirizzi web per istanza

Ogni istanza ha due **ruoli** diversi su internet. Possono stare sul **stesso dominio** o su **due domini**.

| Ruolo | Dove si configura | Formato | A cosa serve |
|-------|-------------------|---------|--------------|
| **Indirizzo pubblico** (app) | `publicBaseUrl` in `config.json` | URL completo (`https://app.example/`) | Dove l'utente apre l'app; dove Supabase rimanda dopo email di conferma o reset password |
| **Indirizzo federativo** (IM) | `im_server_id` in Supabase | Solo dominio (`im.example`) | Identità dell'istanza negli indirizzi messaggi (`mario@im.example`); in futuro anche il server di federazione |

### Stesso dominio (caso più semplice)

```text
publicBaseUrl   = https://arkham-im.fly.dev/
im_server_id    = arkham-im.fly.dev
```

App e federazione (quando ci sarà) usano lo stesso nome.

### Due domini diversi

```text
publicBaseUrl   = https://app.arkham.example/   ← l'utente apre l'app qui
im_server_id    = im.arkham.example             ← gli indirizzi IM finiscono qui
```

Va bene, ma DNS, deploy e redirect Supabase Auth devono essere allineati su entrambi.

### Attenzione

- L'app in uso guarda l'indirizzo del browser; i link condivisi usano quello. Se tutti entrano dall'indirizzo pubblico, coincide con `publicBaseUrl`.
- `im_server_id` non è un soprannome: se è diverso dall'indirizzo dell'app, deve essere un dominio **reale** (con DNS), non solo un nome scelto a caso.
- Evita combinazioni incoerenti (es. app su Fly e `im_server_id` su un dominio che non esiste): deploy e owner vanno d'accordo.

---

## Architettura runtime

| Percorso | Servito da | Fonte dati |
|----------|------------|------------|
| `/`, `/index.html`, `/manifest.json` | Gateway Python `:8091` (proxy nginx) | RPC `get_instance_bootstrap` via `config.json` — **nessuna cache RAM** |
| `/main.dart.js`, `/assets/*`, `/icons/*`, … | nginx statico | Build Flutter (`flutter build web --pwa-strategy=none`) — CanvasKit incluso in immagine |
| `/config.json` | nginx statico | `client/deploy/<istanza>/config.json` (wiring Supabase + `publicBaseUrl`) |
| `/push_sw.js` | nginx statico | `client/web/push_sw.js` (icona da payload push, fallback statico) |

Template gateway: `client/deploy/gateway/templates/`. Il build Flutter **non** include `index.html` / `manifest.json` branded (rimossi post-build nel Dockerfile).

## Build web e avvio (performance)

Il Dockerfile in `client/deploy/shared/` usa:

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
ALFRED_BASE_URL=https://arkham-im.fly.dev/ npx playwright test e2e/demo-live-startup-timing.spec.ts
```

Vedi `client/e2e/demo-live-startup-timing.spec.ts` (metriche: splash hidden, navigazioni, transfer rete).

## Checklist configurazione

| Cosa | Dove | Chi la imposta |
|------|------|----------------|
| Connessione a Supabase + indirizzo pubblico app | `config.json` | Chi fa il deploy |
| Nome e dominio IM iniziali (opzionale) | `instance_config.sql` | Chi fa il deploy |
| Logo, colori, legali, dominio IM | Pannello owner in app | Owner |

Dettaglio: [Come si configura un'istanza](#come-si-configura-unistanza).

Logo e colori della shell **non** vanno editati nei file del deploy: si cambiano dal pannello owner → bucket `instance-branding` in Supabase.

La chiave anon in `config.json` è pubblica per design; non è un segreto.

## Primo deploy

Da **root del repository**, per ogni istanza:

```bash
# 1. Personalizza client/deploy/<istanza>/config.json

# 2. Crea l'app Fly (una tantum) — nome in fly.toml
fly apps create arkham-im      # Arkham
fly apps create blackgate-im   # Blackgate

# Migrazione da alfred-im-web (una tantum, solo Arkham):
# bash scripts/fly-rename-client-app.sh

# 3. Deploy (build remoto Fly)
bash scripts/fly-deploy-client.sh       # Arkham
bash scripts/fly-deploy-blackgate.sh    # Blackgate
```

## Deploy successivi

```bash
bash scripts/fly-deploy-client.sh       # Arkham
bash scripts/fly-deploy-blackgate.sh    # Blackgate
```

**Push su GitHub da solo non deploya Fly.** La CI (`docker-client-fly.yml`) esegue solo smoke build locale. Per pubblicare su Fly serve **`fly deploy`** (manuale) oppure **Auto Deploy** configurato in dashboard (vedi sotto). **Non** usare GitHub Actions con `FLY_API_TOKEN` — il deploy passa da Fly Deployments.

## Auto-deploy al push (opzionale, dashboard Fly)

Integrazione **Fly Deployments ↔ GitHub** — non è nel repo; va abilitata **per app** (una tantum per istanza):

1. Dashboard Fly → app (`arkham-im` o `blackgate-im`) → **Deployments** → **Settings**
2. Collega il repository GitHub
3. Abilita **Auto Deploy** sul branch (es. `main`)
4. **Config path:** `client/deploy/arkham/fly.toml` o `client/deploy/blackgate/fly.toml`
5. **Dockerfile path:** `client/deploy/shared/Dockerfile`
6. **Working directory / monorepo root:** `.` (root del repo)

Se la working directory è la cartella istanza, Fly duplica i path del Dockerfile e il build fallisce.

### Build Flutter fallisce su Depot (`can't be called from trap context`)

Il builder **Depot** (default Fly) può interrompere `flutter build web` dopo pochi secondi. Il Dockerfile è valido (smoke CI locale + `scripts/docker-smoke-client.sh`).

**Workaround dashboard (senza CLI):**

1. Fly → **Organization** → **Settings** → **App Builders** → **Configure**
2. Imposta regione builder vicina a `fra` (es. `ams`, `lhr`) o **Reset** se bloccato su «Waiting for depot builder…»
3. Riprova il deploy da **Deployments** → **Deploy latest commit**

**Deploy manuale (CLI):** gli script `fly-deploy-*.sh` usano `--depot=false` (builder legacy Fly).

La dashboard GitHub **non** espone `--depot=false`; se il workaround regione non basta, contatta Fly support o usa deploy CLI una tantum.

## Dopo il deploy client

Ripetere **per ogni** istanza (Arkham e Blackgate hanno progetti Supabase distinti):

1. **Supabase** — migrazioni in `supabase/migrations/` sul progetto dell'istanza (`tvwpoxxcqwphryvuyqzu` o `jgxkimvjmlfjdtzsuijh`; MCP, `supabase db push`, dashboard). Seed opzionale: `client/deploy/<istanza>/instance_config.sql`. Per branding owner: `20260830100000_instance_branding_storage.sql` (bucket `instance-branding`).
2. **Edge Function** — redeploy `send-push` se cambia il payload push (`supabase/functions/send-push/`).
3. **Supabase Auth** → Redirect URLs: host di `publicBaseUrl` dell'istanza (`https://arkham-im.fly.dev/**` o `https://blackgate-im.fly.dev/**`)
4. Verifica: `GET /` contiene shell dinamica (`alfred-boot-splash`, no commento `$FLUTTER_BASE_HREF`); `GET /manifest.json` risponde JSON da bootstrap (non file statico pre-merge).

## Smoke test locale

```bash
bash scripts/docker-smoke-client.sh
```

## Riferimenti

- Gateway: `client/deploy/gateway/`
- Federazione (host `im_server_id`): contratto wire in `docs/architecture/gotham-protocol.md`
- SDD: `docs/specs/surfaces/SURF-INSTANCE-CONFIG.md`, `docs/specs/surfaces/SURF-AUTH.md`, `docs/specs/promises/system/SYS-OWNER.md`
- [Fly static sites](https://fly.io/docs/languages-and-frameworks/static/)
