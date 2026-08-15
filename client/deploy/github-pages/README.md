# Deploy GitHub Pages (`alfred-im.github.io/alfred-im/`)

Configurazione **istanza** (non software). Tre posti distinti:

| Dove | Cosa | Quando |
|------|------|--------|
| `config.json` | Supabase URL, anon key, `publicBaseUrl` | Copiato in `client/web/` dal workflow prima del build |
| `manifest.json` | Nome PWA, colori, icone | Idem |
| `instance_config.sql` | Nome servizio e `im_server_id` nel DB | Eseguire su Supabase dell'istanza (una tantum o dopo reset DB) |

## Demo attuale (live)

- **display_name:** `Alfred.im Demo`
- **im_server_id:** `alfred.im`

```bash
# Da repo root, con accesso al progetto live:
psql "$DATABASE_URL" -f client/deploy/github-pages/instance_config.sql
```

Oppure incolla il contenuto di `instance_config.sql` nel SQL Editor Supabase.

Per un'altra istanza/hosting, creare una cartella analoga (es. `deploy/my-instance/`) e adattare workflow o processo operatore.
