# Deploy Fly.io — client web (PWA)

**Live (demo istanza):** https://alfred-im-web.fly.dev/

Via canonica per **pubblicare il client** di un'istanza Alfred. Stack container: **nginx** (asset Flutter statici) + **gateway Python** (shell PWA dinamica). I bridge restano sull'app `alfred-im` (root `fly.toml`); il client usa un'**app Fly separata**.

## Architettura runtime

| Percorso | Servito da | Fonte dati |
|----------|------------|------------|
| `/`, `/index.html`, `/manifest.json` | Gateway Python `:8091` (proxy nginx) | RPC `get_instance_bootstrap` via `config.json` — **nessuna cache RAM** |
| `/main.dart.js`, `/assets/*`, `/icons/*`, … | nginx statico | Build Flutter (`flutter build web`) |
| `/config.json` | nginx statico | `client/deploy/fly/config.json` (wiring Supabase + `publicBaseUrl`) |
| `/push_sw.js` | nginx statico | `client/web/push_sw.js` (icona da payload push, fallback statico) |

Template gateway: `client/deploy/gateway/templates/`. Il build Flutter **non** include `index.html` / `manifest.json` branded (rimossi post-build nel Dockerfile).

## Cosa configurare (istanza)

| File | Cosa |
|------|------|
| `config.json` | `supabaseUrl`, `supabaseAnonKey`, `publicBaseUrl` (URL pubblico di questa app Fly) |
| `instance_config.sql` | Opzionale — seed SQL `instance.display_name` / `instance.im_server_id` sul Supabase dell'istanza |

Branding shell/PWA (logo, favicon, colori, manifest) si modifica dal **pannello owner** in app (`SURF-INSTANCE-CONFIG`) → bucket Storage `instance-branding` + chiave `instance.branding`. **Non** editare file statici nel deploy Fly.

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
3. **Supabase Auth** → Redirect URLs: `https://<tua-app>.fly.dev/**` (demo: `https://alfred-im-web.fly.dev/**`)
4. Verifica: `GET /` contiene shell dinamica (`alfred-boot-splash`, no commento `$FLUTTER_BASE_HREF`); `GET /manifest.json` risponde JSON da bootstrap (non file statico pre-merge).

## Smoke test locale

```bash
bash scripts/docker-smoke-client.sh
```

## Riferimenti

- Gateway: `client/deploy/gateway/`
- SDD: `docs/specs/surfaces/SURF-INSTANCE-CONFIG.md`, `docs/specs/promises/system/SYS-OWNER.md`
- Bridge Fly: root `fly.toml` + `scripts/fly-deploy-all.sh`
- [Fly static sites](https://fly.io/docs/languages-and-frameworks/static/)
