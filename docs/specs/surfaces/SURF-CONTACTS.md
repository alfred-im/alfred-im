# SURF-CONTACTS — Rubrica

| Campo | Valore |
|-------|--------|
| **Superficie ID** | `SURF-CONTACTS` |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-08 |
| **Promesse** | [PROM-LIST-FILTER](../promises/product/PROM-LIST-FILTER.md) |
| **Capability legacy** | [CONTACTS.spec.md](../capabilities/CONTACTS.spec.md) (REQ-013 filtro logico) |

Binding filtro lista sulla schermata Contatti. **Non** copre il bottom sheet «Aggiungi contatto» (`search_profiles`).

---

## 1. Superficie

| Elemento | Valore |
|----------|--------|
| Schermata | `client/lib/screens/contacts_screen.dart` |
| Controller | `ContactsController` — `filteredContacts`, `setSearchQuery` |

---

## 2. Promesse SURFACE

### MUST

| ID | Promessa |
|----|----------|
| **SURF-CONTACTS-001** | Conforme a [PROM-LIST-FILTER](../promises/product/PROM-LIST-FILTER.md) |
| **SURF-CONTACTS-002** | Campo filtro: `display_name` del contatto (`filterByQuery` su `displayName`) |
| **SURF-CONTACTS-003** | Hint campo e tooltip lente: «Cerca contatto» |
| **SURF-CONTACTS-004** | Lente nell'`AppBar` (accanto ad azione aggiungi); barra sotto AppBar solo se aperta |

### MUST NOT

| ID | Promessa |
|----|----------|
| **SURF-CONTACTS-010** | Barra «Cerca contatto» sempre visibile (viola PROM-LIST-FILTER-031) |
| **SURF-CONTACTS-011** | Applicare PROM-LIST-FILTER al bottom sheet `_AddContactSheet` (ricerca `search_profiles` resta flusso aggiunta) |

---

## 3. Tracciabilità (target post-implementazione)

| SURF-ID | Verifica prevista |
|---------|-------------------|
| SURF-CONTACTS-001–004 | `contacts_screen.dart`; `contacts_screen_test.dart` |
| SURF-CONTACTS-002 | `contacts_controller.dart`; `list_filter_test.dart` |
| PROM-LIST-FILTER-001–004 | già coperti da test unit |

---

## 4. Riferimenti

- [CONTACTS.spec.md](../capabilities/CONTACTS.spec.md)
- [PROM-LIST-FILTER](../promises/product/PROM-LIST-FILTER.md)
