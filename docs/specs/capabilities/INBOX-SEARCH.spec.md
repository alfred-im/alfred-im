# INBOX-SEARCH — Ricerca on-demand inbox

| Campo | Valore |
|-------|--------|
| **Spec ID** | `INBOX-SEARCH` |
| **Layer** | capability |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-03 |
| **ADR** | — (UX client; dipende da [MAILBOX-INBOX](./MAILBOX-INBOX.spec.md)) |
| **PR** | #132 |
| **Supersedes** | `design/inbox-search-toggle.md` (evidenza UX) |

Documento per AI — contratto ricerca nella lista conversazioni: UI on-demand, filtro client-side, chiusura unificata.

---

## 1. Problema / obiettivo

L’utente deve poter filtrare la lista conversazioni per nome peer, anteprima ultimo messaggio o indirizzo, senza occupare spazio permanente nell’header inbox. La ricerca è **solo client-side** sulla lista già caricata da `list_inbox()`.

---

## 2. Requisiti

### MUST

| ID | Requisito |
|----|-----------|
| **INBOX-SEARCH-REQ-001** | Barra «Cerca messaggi» **nascosta** di default in `InboxPanel` |
| **INBOX-SEARCH-REQ-002** | Apertura: tap icona lente (`Icons.search`) → barra visibile + `requestFocus` sul campo |
| **INBOX-SEARCH-REQ-003** | Filtro: `InboxController.filteredPeers` — substring case-insensitive su `displayName`, `preview`, `address` |
| **INBOX-SEARCH-REQ-004** | Chiusura unificata: **un solo** metodo `_dismissSearch()` in `InboxPanel` (nasconde barra, svuota controller, `onSearchChanged('')` se testo, `unfocus`) |
| **INBOX-SEARCH-REQ-005** | Trigger chiusura: secondo tap lente (toggle); `TapRegion.onTapOutside` (barra + lente stesso `groupId`); `dispose` se filtro attivo |
| **INBOX-SEARCH-REQ-006** | Cambio account: `ValueKey(accountUserId)` su `InboxPanel` in `HomeScreen` → stato ricerca reset |
| **INBOX-SEARCH-REQ-007** | Layout **mobile** (`showTopBar: true`): lente nell’header «Alfred», prima di Contatti; barra sotto header |
| **INBOX-SEARCH-REQ-008** | Layout **desktop** (`showTopBar: false`): lente nella riga «Conversazioni»; barra sotto titolo |

### SHOULD

| ID | Requisito |
|----|-----------|
| **INBOX-SEARCH-REQ-009** | Hint campo: «Cerca messaggi» |
| **INBOX-SEARCH-REQ-010** | Tooltip lente: «Cerca messaggi» |

### MUST NOT

| ID | Requisito |
|----|-----------|
| **INBOX-SEARCH-REQ-011** | Ricerca server-side / RPC dedicata in Alpha |
| **INBOX-SEARCH-REQ-012** | Barra ricerca sempre visibile |
| **INBOX-SEARCH-REQ-013** | Callback sparse in `HomeScreen` (o parent) per chiudere la ricerca su ogni azione |
| **INBOX-SEARCH-REQ-014** | Duplicare logica dismiss fuori da `_dismissSearch()` (o equivalente esposto) |

---

## 3. Fuori scope

- Ricerca nel **contenuto** dei messaggi in chat (solo lista conversazioni).
- Tasto **Indietro** Android / **Escape** web per chiudere (follow-up).
- Navigazione programmatica che chiude ricerca senza tap utente.
- Ricerca full-text su DB.

---

## 4. Contratto

### 4.1 Backend

Nessuno — filtro su `peers` già in memoria da [MAILBOX-INBOX](./MAILBOX-INBOX.spec.md).

### 4.2 Client

| Componente | Responsabilità |
|------------|----------------|
| `InboxPanel` | Stato `_searchVisible`, UI barra, `_dismissSearch`, `_toggleSearch`, `TapRegion` |
| `InboxController.setSearchQuery` | Aggiorna `_searchQuery`, `notifyListeners()` |
| `InboxController.filteredPeers` | `filterByQueryFields` su displayName, preview, address |
| `list_filter.dart` | `filterByQueryFields` — substring case-insensitive |
| `HomeScreen._inboxPanel` | `peers: inbox.filteredPeers`, `onSearchChanged: inbox.setSearchQuery`, `key: ValueKey(accountUserId)` |

### 4.3 UX — flusso

```
Tap lente → barra + focus → digitazione → filteredPeers aggiornata live
Tap fuori / secondo tap lente → _dismissSearch → lista completa
Switch account → nuovo InboxPanel → ricerca chiusa
```

---

## 5. Tracciabilità

| REQ-ID | Verifica |
|--------|----------|
| INBOX-SEARCH-REQ-001, REQ-002, REQ-004, REQ-005 | `inbox_panel.dart` — `_searchVisible`, `_toggleSearch`, `_dismissSearch`, `TapRegion` |
| INBOX-SEARCH-REQ-003 | `list_filter_test.dart` — `filterByQueryFields`; `inbox_controller.dart` `filteredPeers`; `MAILBOX-INBOX.spec.md` REQ-011 |
| INBOX-SEARCH-REQ-006 | `home_screen.dart` — `key: ValueKey(accountUserId)` su `_inboxPanel` |
| INBOX-SEARCH-REQ-007, REQ-008 | `inbox_panel.dart` — layout `showTopBar`; `design/inbox-search-toggle.md` |
| INBOX-SEARCH-REQ-009, REQ-010 | `inbox_panel.dart` — hint e tooltip «Cerca messaggi» |
| INBOX-SEARCH-REQ-011 | Nessuna RPC ricerca; filtro solo su `peers` in memoria |
| INBOX-SEARCH-REQ-012, REQ-013, REQ-014 | `inbox-search-toggle.md` PR #132; dismiss centralizzato in `InboxPanel` |

Gate: `cd client && bash scripts/verify.sh` · Manuale: apri/chiudi ricerca mobile + desktop; tap outside; switch account

---

## 6. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [inbox-search-toggle.md](../../design/inbox-search-toggle.md) | Design originale PR #132 |
| [alpha-full-stack.md](../../architecture/alpha-full-stack.md) §2.12 | Panoramica |
| [MAILBOX-INBOX](./MAILBOX-INBOX.spec.md) | Sorgente dati `peers` |

**Codice**: `client/lib/widgets/inbox_panel.dart`, `providers/inbox_controller.dart`, `utils/list_filter.dart`, `screens/home_screen.dart`
