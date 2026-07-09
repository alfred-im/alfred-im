# Alfred — Piattaforma messaggistica

## Scopo

Traccia lo stato del progetto per continuità del lavoro. Non è documentazione per utenti esterni.

## Stato attuale (2026-07-09)

**Flutter + Supabase + bridge Python**. Prodotto **stabile** (senza versionamento release). PR **#108–#172** su `main`.

| Componente | Stato |
|------------|-------|
| **`client/`** | App Supabase — shell messaggistica, multi-account, ricerca liste on-demand (PROM-LIST-FILTER), allow list, scheda profilo peer, account gruppo, `verify.sh` (**132** test gate) |
| **`supabase/`** | Schema dominio (profiles, contacts, messages per-owner, outbox, …) |
| **`bridge-xmpp/`** · **`bridge-matrix/`** | Stub health Fly.io |

### URL live (demo di sviluppo — **non produzione**)

**https://alfred-im.github.io/XmppTest/** è la **demo di sviluppo** su GitHub Pages: test e CI, **non** produzione. Ogni build CI da PR o `main` aggiorna lo stesso URL (`deploy-pages`). Alfred è software personale open source: **non esiste** deploy di produzione né è previsto.

## Stack

```
Flutter (client/)  →  Supabase (piattaforma)  →  bridge XMPP + bridge Matrix (Fly.io)
```

## Build locale

```bash
cd client
bash scripts/test.sh gate   # gate CI — obbligatorio prima di git push
flutter run -d web-server --web-port=8080 --web-hostname=0.0.0.0
```

Suite test: `client/scripts/test/README.md`

Deploy: `.github/workflows/deploy-pages.yml`.

## Documentazione

| File | Contenuto |
|------|-----------|
| `PROJECT_MAP.md` | Mappa progetto (leggere a ogni sessione) |
| `docs/specs/registry.md` | **Registro promesse SDD** (ingresso contratti) |
| `docs/INDICE.md` | Indice per area |
| `docs/SESSION_HANDOFF.md` | Handoff rapido per agenti |
| `docs/architecture/full-stack.md` | Architettura client + Supabase |
| `docs/architecture/pr-registry.md` | Registro PR → documentazione |

---

**Ultimo aggiornamento**: 2026-07-09

- **Supabase**: `tvwpoxxcqwphryvuyqzu` (EU) — `deploy/supabase.json`
- **Fly.io**: `xmpptest` — `deploy/fly-bridges.json`

## License

MIT — `LICENSE`

## Infrastruttura
