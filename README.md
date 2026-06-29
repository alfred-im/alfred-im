# Alfred — Piattaforma messaggistica

## Scopo

Traccia lo stato del progetto per continuità del lavoro. Non è documentazione per utenti esterni.

## Stato attuale (2026-06-29)

**Flutter + Supabase + bridge Python** (`docs/decisions/project-revolution-discovery.md`). PR Alpha **#108–#143** su `main` (multi-account sessioni parallele + fix logout/chat/persistenza #143).

| Componente | Stato |
|------------|-------|
| **`client/`** | App Supabase — shell messaggistica, N sessioni account parallele, overlay auth, chat testo/GIF/voice, `verify.sh` |
| **`supabase/`** | Schema dominio (profiles, contacts, messages, outbox, …) |
| **`bridge-xmpp/`** · **`bridge-matrix/`** | Stub health Fly.io |

### URL live

**https://alfred-im.github.io/XmppTest/** — ambiente Alpha/sviluppo. Ogni build CI da PR o `main` aggiorna lo stesso URL (`deploy-alpha`).

## Stack

```
Flutter (client/)  →  Supabase (piattaforma)  →  bridge XMPP + bridge Matrix (Fly.io)
```

## Build locale

```bash
cd client
bash scripts/verify.sh   # obbligatorio prima di git push
flutter run -d chrome
```

Deploy: `.github/workflows/deploy-pages.yml`.

## Documentazione

| File | Contenuto |
|------|-----------|
| `PROJECT_MAP.md` | Mappa progetto (leggere a ogni sessione) |
| `docs/INDICE.md` | Indice per area |
| `docs/architecture/alpha-full-stack.md` | Architettura Alpha |
| `docs/architecture/alpha-pr-registry.md` | Registro PR → documentazione |

## Infrastruttura

- **Supabase**: `tvwpoxxcqwphryvuyqzu` (EU) — `deploy/supabase.json`
- **Fly.io**: `xmpptest` — `deploy/fly-bridges.json`

## License

MIT — `LICENSE`

---

**Ultimo aggiornamento**: 2026-06-28
