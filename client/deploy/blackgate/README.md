# Deploy Fly.io — Blackgate (second demo instance)

**Target URL:** https://blackgate-im.fly.dev/  
**Supabase project:** `jgxkimvjmlfjdtzsuijh` (org Gotham)

Stesso stack di Arkham: Dockerfile condiviso (`client/deploy/fly/Dockerfile`), `config.json` e `fly.toml` dedicati.

## Prima volta (operator)

### 1. Supabase

Progetto `blackgate-im` — migrazioni da `supabase/migrations/` (applicate via MCP al setup).

- Seed opzionale: `client/deploy/blackgate/instance_config.sql`
- Auth → Redirect URLs: `https://blackgate-im.fly.dev/**`

### 2. Fly (dashboard, dal telefono)

1. Crea app **`blackgate-im`** (region `fra`)
2. **Deployments** → collega GitHub → Auto Deploy `main`
3. **Config path:** `client/deploy/blackgate/fly.toml`
4. **Working directory:** `.` (root repo)
5. Dopo il primo deploy: **Overview** → assegna **IPv4** (shared) + **IPv6** se manca DNS

### 3. Deploy CLI (alternativa)

```bash
bash scripts/fly-deploy-blackgate.sh
```

Usa `--depot=false` e `INSTANCE_CONFIG_JSON=client/deploy/blackgate/config.json`.

## Owner

L'owner non si registra da solo: dopo signup, promuovi con SQL:

```sql
update public.profiles set profile_kind = 'owner' where username = '<username>';
```

Vedi `docs/specs/promises/system/SYS-OWNER.md`.

## Riferimenti

- Arkham (prima istanza): `client/deploy/fly/README.md`
- Architettura istanze: `client/deploy/fly/README.md` § Come si configura un'istanza
