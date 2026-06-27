# Alfred — Piattaforma messaggistica

## Scopo di questo documento

Traccia lo stato del progetto Alfred per continuità del lavoro. NON è documentazione per utenti esterni.

## Stato attuale (2026-06-24)

Migrazione verso **Flutter + Supabase + bridge Python** (`docs/decisions/project-revolution-discovery.md`). PR Alpha **#108–#115** mergiate su `main` (registro: `docs/architecture/alpha-pr-registry.md`).

| Componente | Stato |
|------------|-------|
| **`client/`** (Flutter) | App completa Supabase — auth, chat testo/GIF, aggancio al fondo, contatti, multi-account |
| **`supabase/`** | Schema dominio Alfred (profiles, contacts, messages, outbox, …) |
| **`bridge-xmpp/`** · **`bridge-matrix/`** | Stub health Fly.io — logica **non** implementata |
| **`web-client/`** (React) | **Rimosso** — tag `legacy/web-client-final` |

### URL live

**https://alfred-im.github.io/XmppTest/** — client Flutter + Supabase (auth, chat testo/GIF, contatti, multi-account).

### Client legacy React

```bash
git checkout legacy/web-client-final -- web-client/
```

Commit `6e792eb`. La documentazione in `docs/` descrive architettura sync, spunte XEP, fix — da tradurre in Flutter.

## Stack target

```
Flutter (client/)  →  Supabase (piattaforma)  →  bridge XMPP + bridge Matrix (Fly.io)
```

## Build locale (Flutter)

```bash
cd client
flutter pub get
flutter run -d chrome
flutter build web --release --base-href "/XmppTest/"
```

Deploy automatico su push a `main` via `.github/workflows/deploy-pages.yml`.

## Documentazione

| File | Contenuto |
|------|-----------|
| `PROJECT_MAP.md` | Mappa progetto (leggere a ogni sessione) |
| `docs/architecture/alpha-full-stack.md` | Architettura Alpha Flutter + Supabase |
| `docs/architecture/alpha-pr-registry.md` | Registro PR Alpha → feature → documentazione |
| `docs/decisions/project-revolution-discovery.md` | Visione e Alpha |
| `docs/INDICE.md` | Indice per area |

**Nota**: percorsi `web-client/` nei doc = riferimento al tag legacy.

## Infrastruttura cloud

- **Supabase**: `tvwpoxxcqwphryvuyqzu` (EU) — `deploy/supabase.json`
- **Fly.io**: `xmpptest` — XMPP :443, Matrix :8081 — `deploy/fly-bridges.json`

## License

MIT — `LICENSE`

---

**Ultimo aggiornamento**: 2026-06-24  
**Live**: Flutter + Supabase @ GitHub Pages  
**Legacy**: React @ `legacy/web-client-final`
