# Alfred — Piattaforma messaggistica

## Scopo di questo documento

Traccia lo stato del progetto Alfred per continuità del lavoro. NON è documentazione per utenti esterni.

## Stato attuale (2026-06-24)

Il repository è in **migrazione** dalla rivoluzione documentata in `docs/decisions/project-revolution-discovery.md`.

| Componente | Stato |
|------------|-------|
| **`client/`** (Flutter) | UI mock chat (web + scaffold multi-piattaforma) |
| **`supabase/`** | Piattaforma — bootstrap schema |
| **`bridge-xmpp/`** · **`bridge-matrix/`** | Demoni Python su Fly.io (health OK) |
| **`web-client/`** (React) | **Rimosso da `main`** |

### Client legacy React

L'ultimo snapshot completo del client XMPP React è sul tag git:

```bash
git checkout legacy/web-client-final
```

- **Commit**: `6e792eb`
- **Recupero parziale**: `git checkout legacy/web-client-final -- web-client/`

La documentazione in `docs/` descrive architettura, sync, spunte XEP, fix — da usare come riferimento per il nuovo software Flutter.

## Stack target

```
Flutter (client/)  →  Supabase (piattaforma)  →  bridge XMPP + bridge Matrix (Fly.io)
```

- Login solo con identità **Alfred** (non XMPP/Matrix diretto)
- Federazione XMPP/Matrix invisibile all'utente (bridge)
- Brand invariato (`#2D2926`, spunta, UI stile WhatsApp)

## Documentazione

| Priorità | File | Quando |
|----------|------|--------|
| Obbligatorio | `PROJECT_MAP.md` | Architettura e stato repository |
| Visione nuova | `docs/decisions/project-revolution-discovery.md` | Stack target e Alpha |
| Indice | `docs/INDICE.md` | Navigazione per area |

**Nota sui percorsi `web-client/` nei doc**: molti file in `docs/` citano ancora il client React — sono **riferimenti storici** validi al tag `legacy/web-client-final`.

## Build e preview locale (Flutter)

```bash
cd client
flutter pub get
flutter run -d chrome          # dev
flutter build web --release --base-href "/XmppTest/"
```

**GitHub Pages**: https://alfred-im.github.io/XmppTest/ — deploy automatico su push a `main` (cartella `client/`).

## Infrastruttura cloud (bootstrap)

- **Supabase**: progetto `tvwpoxxcqwphryvuyqzu` (EU) — vedi `deploy/supabase.json`
- **Fly.io**: app `xmpptest` — bridge XMPP (443) + Matrix (8081)

## Credenziali test (legacy XMPP)

Vedi `TEST_CREDENTIALS.md` — utili per testare il client al tag legacy o per sviluppo bridge.

## License

MIT — vedi `LICENSE`

---

**Ultimo aggiornamento**: 2026-06-24  
**Architettura attiva**: Flutter + Supabase + bridge (Alpha)  
**Legacy**: React XMPP @ `legacy/web-client-final`
