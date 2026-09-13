# SURF-ALLOWLIST — Persone consentite

| Campo | Valore |
|-------|--------|
| **Superficie ID** | `SURF-ALLOWLIST` |
| **Status** | `approved` |
| **Ultima revisione** | 2026-09-13 |
| **Promesse** | [PROM-LIST-FILTER](../promises/product/PROM-LIST-FILTER.md), [PROM-RECEPTION-FILTER](../promises/product/PROM-RECEPTION-FILTER.md), [SYS-RECEPTION](../promises/system/SYS-RECEPTION.md) |
| **PR** | #161 |
| **Amend** | gate su `allowed_address` — distillazione TEMP §7 |

Binding completo schermata «Persone consentite»: filtro lista, aggiunta/rimozione manuale per indirizzo, controller per account in focus. Una voce = un `allowed_address` lowercase; `mario` e `mario@mio_server` = voci distinte.

---

## 1. Superficie

| Elemento | Valore |
|----------|--------|
| Schermata | `client/lib/screens/allowed_people_screen.dart` — titolo **«Persone consentite»** |
| Controller | `ReceptionAllowlistController` — `filteredAllowedPeople`, `setSearchQuery`, `archiveUserId` = focus |
| Servizio | `ReceptionAllowlistService` — CRUD PostgREST su `allowed_address` |
| Sheet | `_AddAllowedPersonSheet` — ricerca `search_profiles` o inserimento indirizzo |
| Navigazione | `HomeScreen` → da icona inbox ([SURF-INBOX](./SURF-INBOX.md) SURF-INBOX-007) |
| Presentazione | `get_profiles(addresses[])` batch — fallback indirizzo grezzo |

---

## 2. Promesse SURFACE

### MUST — filtro lista

| ID | Promessa |
|----|----------|
| **SURF-ALLOWLIST-001** | Conforme a [PROM-LIST-FILTER](../promises/product/PROM-LIST-FILTER.md) |
| **SURF-ALLOWLIST-002** | Campo filtro: `displayName` (da `get_profiles`) e `address` (`allowed_address`) (`filterByQueryFields`) |
| **SURF-ALLOWLIST-003** | Hint campo e tooltip lente: «Cerca nella lista» |
| **SURF-ALLOWLIST-004** | Lente nell'`AppBar` (accanto ad azione aggiungi); barra sotto AppBar solo se aperta |

### MUST — gestione lista

| ID | Promessa |
|----|----------|
| **SURF-ALLOWLIST-005** | `ReceptionAllowlistController` legato all'account in **focus** |
| **SURF-ALLOWLIST-006** | Aggiunta manuale: ricerca `search_profiles` (min 2 caratteri) **oppure** inserimento `username` / `user@server` → insert `allowed_address` lowercase |
| **SURF-ALLOWLIST-007** | Rimozione persona dalla lista (swipe o azione equivalente) per `allowed_address` |
| **SURF-ALLOWLIST-008** | Tap avatar persona → [SURF-PEER-PROFILE](./SURF-PEER-PROFILE.md) con switch Allow precompilato |
| **SURF-ALLOWLIST-009** | Lista vuota (UI): messaggio esplicativo — nessuno può consegnarti messaggi finché non aggiungi qualcuno |
| **SURF-ALLOWLIST-012** | `mario` e `mario@mio_server` = **voci distinte** — nessuna fusione automatica |

### SHOULD

| ID | Promessa |
|----|----------|
| **SURF-ALLOWLIST-010** | Lista ordinata per `displayName` (da `get_profiles`) o `address` |
| **SURF-ALLOWLIST-011** | Dopo add/remove: reload lista client |

### MUST NOT

| ID | Promessa |
|----|----------|
| **SURF-ALLOWLIST-020** | Barra «Cerca nella lista» sempre visibile (viola PROM-LIST-FILTER-031) |
| **SURF-ALLOWLIST-021** | Applicare PROM-LIST-FILTER al bottom sheet `_AddAllowedPersonSheet` |
| **SURF-ALLOWLIST-022** | Toggle globale on/off della funzionalità allow list |
| **SURF-ALLOWLIST-023** | Usare rubrica (`contacts`) come fonte o proxy dell'allow list |
| **SURF-ALLOWLIST-024** | Gate allow list su UUID profilo — deriva schema UUID-centrico |

---

## 4. Tracciabilità

| SURF-ID | Verifica |
|-------------------------|----------|
| SURF-ALLOWLIST-002 | `reception_allowlist_controller_test.dart` — `filteredAllowedPeople` |
| SURF-ALLOWLIST-001–004 | `allowed_people_screen.dart`; `allowed_people_screen_test.dart` |
| SURF-ALLOWLIST-005–007 | `reception_allowlist_controller_test.dart`; `allowed_people_screen_test.dart` |
| SURF-ALLOWLIST-009 | `allowed_people_screen.dart` — empty state |
| SURF-ALLOWLIST-011 | `reception_allowlist_controller.dart` — reload dopo add/remove |
| SURF-ALLOWLIST-012 | Review spec — voci distinte bare vs FQDN |

Gate: `cd client && bash scripts/verify.sh`

---

## 5. Riferimenti

- [SYS-RECEPTION.md](../promises/system/SYS-RECEPTION.md)
- [SURF-INBOX.md](./SURF-INBOX.md)
- [SURF-PEER-PROFILE.md](./SURF-PEER-PROFILE.md)
- [PROM-LIST-FILTER](../promises/product/PROM-LIST-FILTER.md)
- [PROM-CHAT-PEER-KEY](../promises/product/PROM-CHAT-PEER-KEY.md)
- [registry.md](../registry.md)
