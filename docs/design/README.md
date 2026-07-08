# Design — Riferimenti tecnici

Principi UI per il client Flutter. Documento per AI.

> **SDD**: i contratti vivono in [specs/registry.md](../specs/registry.md) (PROM/SURF). I file qui sono **evidenza storica** o backlog promesse non ancora distillate.

| File | Contenuto | Contratto v2 |
|------|-----------|----------------|
| [conversation-bottom-anchor.md](./conversation-bottom-anchor.md) | Scroll ancorato in chat | backlog `PROM-BOTTOM-ANCHOR` |
| [inbox-search-toggle.md](./inbox-search-toggle.md) | Ricerca lista on-demand | [PROM-LIST-FILTER](../specs/promises/product/PROM-LIST-FILTER.md) |
| [auth-overlay-shell.md](./auth-overlay-shell.md) | Shell + overlay credenziali | [PROM-MULTI-ACCOUNT](../specs/promises/product/PROM-MULTI-ACCOUNT.md), [SURF-AUTH](../specs/surfaces/SURF-AUTH.md) |

**Brand**: colore `#2D2926` — `client/lib/theme/alfred_colors.dart`  
**Logo**: `client/lib/widgets/alfred_logo.dart`  
**Layout**: responsive stile WhatsApp Web — `PROJECT_MAP.md`
