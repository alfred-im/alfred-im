# SURF-ALLOWLIST — Persone consentite

| Campo | Valore |
|-------|--------|
| **Superficie ID** | `SURF-ALLOWLIST` |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-08 |
| **Promesse** | [PROM-LIST-FILTER](../promises/product/PROM-LIST-FILTER.md) |
| **Capability legacy** | [RECEPTION-ALLOWLIST.spec.md](../capabilities/RECEPTION-ALLOWLIST.spec.md) |

Binding filtro lista sulla schermata «Persone consentite». **Non** copre il bottom sheet «Aggiungi persona» (`search_profiles`).

---

## 1. Superficie

| Elemento | Valore |
|----------|--------|
| Schermata | `client/lib/screens/allowed_people_screen.dart` |
| Controller | `ReceptionAllowlistController` — `filteredAllowedPeople`, `setSearchQuery` |

---

## 2. Promesse SURFACE

### MUST

| ID | Promessa |
|----|----------|
| **SURF-ALLOWLIST-001** | Conforme a [PROM-LIST-FILTER](../promises/product/PROM-LIST-FILTER.md) |
| **SURF-ALLOWLIST-002** | Campo filtro: `display_name` della persona (`filterByQuery` su `displayName`) |
| **SURF-ALLOWLIST-003** | Hint campo e tooltip lente: «Cerca nella lista» |
| **SURF-ALLOWLIST-004** | Lente nell'`AppBar` (accanto ad azione aggiungi); barra sotto AppBar solo se aperta |

### MUST NOT

| ID | Promessa |
|----|----------|
| **SURF-ALLOWLIST-010** | Barra «Cerca nella lista» sempre visibile (viola PROM-LIST-FILTER-031) |
| **SURF-ALLOWLIST-011** | Applicare PROM-LIST-FILTER al bottom sheet `_AddAllowedPersonSheet` |

---

## 3. Tracciabilità

| SURF-ID | Verifica |
|---------|----------|
| SURF-ALLOWLIST-002 | `reception_allowlist_controller_test.dart` — `filteredAllowedPeople` |
| SURF-ALLOWLIST-001–004 | `allowed_people_screen.dart`; `allowed_people_screen_test.dart` |

---

## 4. Riferimenti

- [RECEPTION-ALLOWLIST.spec.md](../capabilities/RECEPTION-ALLOWLIST.spec.md)
- [PROM-LIST-FILTER](../promises/product/PROM-LIST-FILTER.md)
