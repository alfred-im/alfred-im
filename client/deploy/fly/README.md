# Deploy Fly.io — client web (PWA)

Via canonica per **pubblicare il client** di un'istanza Alfred (static Flutter + nginx). I bridge restano sull'app `alfred-im` (root `fly.toml`); il client usa un'**app Fly separata**.

## Cosa configurare (istanza)

| File | Cosa |
|------|------|
| `config.json` | `supabaseUrl`, `supabaseAnonKey`, `publicBaseUrl` (URL pubblico di questa app Fly) |
| `manifest.json` | Nome PWA, colori, icone (statico finché non c'è gateway dinamico) |
| `instance_config.sql` | Opzionale — stesso script di [`../github-pages/instance_config.sql`](../github-pages/instance_config.sql) sul Supabase dell'istanza |

La anon key in `config.json` è pubblica per design (SPA); non è un secret runtime.

## Primo deploy

Da **root del repository**:

```bash
# 1. Personalizza client/deploy/fly/config.json (e manifest.json se serve)

# 2. Crea l'app (una tantum) — cambia il nome in fly.toml se necessario
fly apps create alfred-im-web   # oppure fly launch --config client/deploy/fly/fly.toml --no-deploy

# 3. Deploy (build remoto Fly)
bash scripts/fly-deploy-client.sh
```

## Deploy successivi

```bash
bash scripts/fly-deploy-client.sh
```

## Auto-deploy al push (senza GitHub Actions)

1. Dashboard Fly → app client → **Deployments** → **Settings**
2. Collega il repository GitHub
3. Abilita **Auto Deploy** sul branch (es. `main`)
4. Imposta **Dockerfile path**: `Dockerfile` (relativo a `client/deploy/fly/`, dove sta `fly.toml`)
5. **Working directory / monorepo root:** `.` (root del repo) — **non** `client/deploy/fly`

Se la working directory è `client/deploy/fly`, Fly cerca `client/deploy/fly/client/deploy/fly/Dockerfile` e il build fallisce.

Ogni push sul branch scelto ridistribuisce il client. In monorepo il client si ribuilda anche su push che non toccano `client/` — accettabile per fork operatore; altrimenti deploy manuale.

### Errore `client/deploy/fly/client/deploy/fly/Dockerfile not found`

La **working directory** in Fly Deployments → Settings è impostata sulla sottocartella invece che sulla root del repo. Imposta **`.`** (root) e lascia config path `client/deploy/fly/fly.toml`.

## Dopo il deploy

1. **Supabase Auth** → Redirect URLs: `https://<tua-app>.fly.dev/**`
2. Esegui `instance_config.sql` sul progetto Supabase dell'istanza
3. Verifica: `https://<tua-app>.fly.dev/` carica la PWA; `config.json` risponde 200

## Smoke test locale

```bash
bash scripts/docker-smoke-client.sh
```

## Riferimenti

- Demo GitHub Pages: [`../github-pages/`](../github-pages/)
- Bridge Fly: root `fly.toml` + `scripts/fly-deploy-all.sh`
- [Fly static sites](https://fly.io/docs/languages-and-frameworks/static/)
