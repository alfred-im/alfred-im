# Ricerca on-demand nella lista conversazioni

> **Superseded by spec**: [PROM-LIST-FILTER.md](../specs/promises/product/PROM-LIST-FILTER.md) + [SURF-INBOX.md](../specs/surfaces/SURF-INBOX.md) — design UX PR #132; per contratto usare le promesse.

**Data**: 2026-06-28  
**Status**: Evidenza UX — implementata in client Flutter (PR #132, refactor #171)  
**Categoria**: Inbox, UX, layout  
**Correlata**: [alpha-full-stack.md](../architecture/alpha-full-stack.md) §2.12

---

## Concept

La ricerca nella **lista conversazioni** (`InboxPanel`) non è sempre visibile. L’utente la apre con un’icona lente; si chiude con tap fuori dalla barra o secondo tap sulla lente. Alla chiusura il filtro testuale si **azzera** (lista completa).

Filtro client-side su `InboxController.filteredPeers` — stesso meccanismo di prima, solo UI on-demand.

---

## Layout

| Contesto | Header | Ricerca |
|----------|--------|---------|
| **Mobile** (`showTopBar: true`) | Barra scura «Alfred» — lente a destra, prima di Contatti | Barra sotto header, solo se aperta |
| **Desktop** (`showTopBar: false`) | Riga «Conversazioni» + lente + Contatti | Barra sotto la riga titolo, solo se aperta |

Apertura: tap lente → barra visibile + `requestFocus` sul campo.

---

## Regole di chiusura (vincolanti)

**Un solo widget**: `CollapsibleListSearch` — nasconde barra, svuota controller, chiama `onQueryChanged('')`, toglie focus. Superfici non duplicano stato `_searchVisible` / dismiss.

| Trigger | Meccanismo |
|---------|------------|
| Secondo tap sulla lente | Toggle esplicito |
| Tap fuori da barra + lente | `TapRegion` con `groupId` condiviso — `onTapOutside` → dismiss centralizzato |
| Smontaggio widget | `dispose` — azzera filtro se ancora attivo |
| Cambio account | `ValueKey(userId)` su `InboxPanel` in `HomeScreen` — widget nuovo, stato ricerca reset |

**Vietato**: liste di callback sparse in parent per chiudere la ricerca (contatti, drawer, selezione peer, ecc.). Il tap-outside copre le interazioni utente senza enumerare le azioni.

### Non coperto in Alpha (follow-up)

- Tasto **Indietro** (Android) / **Escape** (web)
- Navigazione programmatica senza tap utente

Estensioni future devono usare `CollapsibleListSearch` (o API equivalente), non duplicare logica dismiss.

---

## Implementazione Flutter

| Elemento | Percorso |
|----------|----------|
| Widget condiviso ricerca | `client/lib/widgets/collapsible_list_search.dart` |
| Inbox (lente + barra) | `client/lib/widgets/inbox_panel.dart` |
| Contatti / allow list | `client/lib/screens/contacts_screen.dart`, `allowed_people_screen.dart` |
| Filtro inbox | `client/lib/providers/inbox_controller.dart` |
| `Key` account | `client/lib/screens/home_screen.dart` |

**Tecnica**: `TapRegion` — barra e lente nello stesso `groupId`; `onTapOutside` solo mentre ricerca visibile.

---

## Riferimenti

- [alpha-full-stack.md](../architecture/alpha-full-stack.md) — §2.12
- `PROJECT_MAP.md` — layout inbox
- PR #132
