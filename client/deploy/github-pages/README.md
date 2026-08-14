# Deploy GitHub Pages (`alfred-im.github.io/alfred-im/`)

Configurazione **istanza** (non software): il workflow `deploy-client` copia questi file in `client/web/` prima del build.

- `config.json` — Supabase URL, anon key, `publicBaseUrl`
- `manifest.json` — nome PWA e metadati installazione

Per un’altra istanza/hosting, creare una cartella analoga (es. `deploy/my-instance/`) e adattare il workflow o il processo di deploy dell’operatore.
