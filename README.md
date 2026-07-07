# Alfred — Piattaforma messaggistica

## Scopo

Traccia lo stato del progetto per continuità del lavoro. Non è documentazione per utenti esterni.

## Stato attuale (2026-07-07)

**Flutter + Supabase + bridge Python**. PR Alpha **#108–#163** su `main` (scheda profilo peer #163).

| Componente | Stato |
|------------|-------|
| **`client/`** | App Supabase — shell messaggistica, multi-account (manifest + focus), overlay auth, chat testo/GIF/voice/location, modello caselle mailbox, allow list ricezione («Persone consentite»), **scheda profilo peer** (tap avatar), **account gruppo** (shell dedicata, erogazione, UI autore), `verify.sh` (**108** test gate) |
| **`supabase/`** | Schema dominio (profiles, contacts, messages per-owner, outbox, …) |
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
bash scripts/test.sh gate   # gate CI — obbligatorio prima di git push
flutter run -d web-server --web-port=8080 --web-hostname=0.0.0.0
```

Suite test: `client/scripts/test/README.md`

Deploy: `.github/workflows/deploy-pages.yml`.

## Documentazione

| File | Contenuto |
|------|-----------|
| `PROJECT_MAP.md` | Mappa progetto (leggere a ogni sessione) |
| `docs/INDICE.md` | Indice per area |
| `docs/SESSION_HANDOFF.md` | Handoff rapido per agenti |
| `docs/architecture/alpha-full-stack.md` | Architettura Alpha |
| `docs/architecture/alpha-pr-registry.md` | Registro PR → documentazione |

## Infrastruttura

- **Supabase**: `tvwpoxxcqwphryvuyqzu` (EU) — `deploy/supabase.json`
- **Fly.io**: `xmpptest` — `deploy/fly-bridges.json`

## License

MIT — `LICENSE`

---

**Ultimo aggiornamento**: 2026-07-07
