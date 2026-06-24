# Alfred — Piattaforma messaggistica

## Scopo di questo documento

Traccia lo stato del progetto Alfred per continuità del lavoro. NON è documentazione per utenti esterni.

## Stato attuale (2026-06-24)

Migrazione verso **Flutter + Supabase + bridge Python** (`docs/decisions/project-revolution-discovery.md`). PR #107 e #108 mergiate su `main`; branch feature eliminati.

| Componente | Stato |
|------------|-------|
| **`client/`** (Flutter) | App completa collegata a Supabase — live su GitHub Pages |
| **`supabase/`** | Schema dominio Alfred (profiles, contacts, messages, outbox, …) |
| **`bridge-xmpp/`** · **`bridge-matrix/`** | Stub health Fly.io — logica **non** implementata |
| **`web-client/`** (React) | **Rimosso** — tag `legacy/web-client-final` |

### URL live

**https://alfred-im.github.io/XmppTest/** — client Flutter collegato a Supabase (auth, chat, contatti).

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
