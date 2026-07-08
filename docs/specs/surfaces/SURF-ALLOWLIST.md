# SURF-ALLOWLIST — Persone consentite

| Campo | Valore |
|-------|--------|
| **Superficie ID** | `SURF-ALLOWLIST` |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-08 |
| **Promesse** | [PROM-LIST-FILTER](../promises/product/PROM-LIST-FILTER.md), [SYS-RECEPTION](../promises/system/SYS-RECEPTION.md) |
| **PR** | #161 |

Binding completo schermata «Persone consentite»: filtro lista, aggiunta/rimozione manuale, controller per account in focus.

---

## 1. Superficie

| Elemento | Valore |
|----------|--------|
| Schermata | `client/lib/screens/allowed_people_screen.dart` — titolo **«Persone consentite»** |
| Controller | `ReceptionAllowlistController` — `filteredAllowedPeople`, `setSearchQuery`, `ownerId` = focus |
| Servizio | `ReceptionAllowlistService` — CRUD PostgREST + join profili |
| Sheet | `_AddAllowedPersonSheet` — ricerca `search_profiles` |
| Navigazione | `HomeScreen` → da icona inbox ([SURF-INBOX](./SURF-INBOX.md) SURF-INBOX-007) |

---

## 2. Promesse SURFACE

### MUST — filtro lista

| ID | Promessa |
|----|----------|
| **SURF-ALLOWLIST-001** | Conforme a [PROM-LIST-FILTER](../promises/product/PROM-LIST-FILTER.md) |
| **SURF-ALLOWLIST-002** | Campo filtro: `display_name` della persona (`filterByQuery` su `displayName`) |
| **SURF-ALLOWLIST-003** | Hint campo e tooltip lente: «Cerca nella lista» |
| **SURF-ALLOWLIST-004** | Lente nell'`AppBar` (accanto ad azione aggiungi); barra sotto AppBar solo se aperta |

### MUST — gestione lista

| ID | Promessa |
|----|----------|
| **SURF-ALLOWLIST-005** | `ReceptionAllowlistController` legato all'account in **focus** |
| **SURF-ALLOWLIST-006** | Aggiunta manuale persona: ricerca `search_profiles` (min 2 caratteri, come rubrica) → selezione → insert |
| **SURF-ALLOWLIST-007** | Rimozione persona dalla lista (swipe o azione equivalente) |
| **SURF-ALLOWLIST-008** | Tap avatar persona → [SURF-PEER-PROFILE](./SURF-PEER-PROFILE.md) con switch Allow precompilato |
| **SURF-ALLOWLIST-009** | Lista vuota (UI): messaggio esplicativo — nessuno può consegnarti messaggi finché non aggiungi qualcuno |

### SHOULD

| ID | Promessa |
|----|----------|
| **SURF-ALLOWLIST-010** | Lista ordinata per `display_name` del profilo consentito |
| **SURF-ALLOWLIST-011** | Dopo add/remove: reload lista client |

### MUST NOT

| ID | Promessa |
|----|----------|
| **SURF-ALLOWLIST-020** | Barra «Cerca nella lista» sempre visibile (viola PROM-LIST-FILTER-031) |
| **SURF-ALLOWLIST-021** | Applicare PROM-LIST-FILTER al bottom sheet `_AddAllowedPersonSheet` |
| **SURF-ALLOWLIST-022** | Toggle globale on/off della funzionalità allow list |
| **SURF-ALLOWLIST-023** | Usare rubrica (`contacts`) come fonte o proxy dell'allow list |

---

## 4. Tracciabilità

| SURF-ID | Verifica |
|-------------------------|----------|
| SURF-ALLOWLIST-002 | `reception_allowlist_controller_test.dart` — `filteredAllowedPeople` |
| SURF-ALLOWLIST-001–004 | `allowed_people_screen.dart`; `allowed_people_screen_test.dart` |
| SURF-ALLOWLIST-005–007 | `reception_allowlist_controller_test.dart`; `allowed_people_screen_test.dart` |
| SURF-ALLOWLIST-009 | `allowed_people_screen.dart` — empty state |
| SURF-ALLOWLIST-011 | `reception_allowlist_controller.dart` — reload dopo add/remove |

Gate: `cd client && bash scripts/verify.sh`

---

## 5. Riferimenti

- [SYS-RECEPTION.md](../promises/system/SYS-RECEPTION.md)
- [SURF-INBOX.md](./SURF-INBOX.md)
- [SURF-PEER-PROFILE.md](./SURF-PEER-PROFILE.md)
- [PROM-LIST-FILTER](../promises/product/PROM-LIST-FILTER.md)
- [registry.md](../registry.md)
