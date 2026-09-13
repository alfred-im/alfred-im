# SURF-CONTACTS — Rubrica

| Campo | Valore |
|-------|--------|
| **Superficie ID** | `SURF-CONTACTS` |
| **Status** | `approved` |
| **Ultima revisione** | 2026-09-13 |
| **Promesse** | [PROM-LIST-FILTER](../promises/product/PROM-LIST-FILTER.md), [PROM-PERSONAL-CONTACTS](../promises/product/PROM-PERSONAL-CONTACTS.md), [SYS-CONTACTS](../promises/system/SYS-CONTACTS.md) |
| **PR** | #109, #134 |
| **Amend** | rubrica solo `address` + `get_profiles` — distillazione TEMP §7 |

Binding completo schermata Contatti: filtro lista, aggiunta per indirizzo, compose, controller per account in focus. **`contacts` salva soltanto `address` lowercase** — presentazione via `get_profiles`.

---

## 1. Superficie

| Elemento | Valore |
|----------|--------|
| Schermata | `client/lib/screens/contacts_screen.dart` |
| Controller | `ContactsController` — `filteredContacts`, `setSearchQuery`, `archiveUserId` = focus |
| Servizi | `ContactService`, `ComposeService.peerFromContact` |
| Sheet | `_AddContactSheet` — ricerca profili o inserimento indirizzo |
| Presentazione | `get_profiles(addresses[])` batch — fallback indirizzo grezzo |

---

## 2. Promesse SURFACE

### MUST — filtro lista

| ID | Promessa |
|----|----------|
| **SURF-CONTACTS-001** | Conforme a [PROM-LIST-FILTER](../promises/product/PROM-LIST-FILTER.md) |
| **SURF-CONTACTS-002** | Campo filtro: `displayName` (da `get_profiles`) e `address` del contatto (`filterByQueryFields`) |
| **SURF-CONTACTS-003** | Hint campo e tooltip lente: «Cerca contatto» |
| **SURF-CONTACTS-004** | Lente nell'`AppBar` (accanto ad azione aggiungi); barra sotto AppBar solo se aperta |

### MUST — rubrica e compose

| ID | Promessa |
|----|----------|
| **SURF-CONTACTS-005** | `ContactsController` legato all'account in **focus** (`ChangeNotifierProxyProvider` + `archiveUserId`) |
| **SURF-CONTACTS-006** | Aggiunta: `search_profiles` (min 2 caratteri) → selezione → insert con `address` lowercase |
| **SURF-CONTACTS-007** | Aggiunta per indirizzo: form `username` o `user@server` → insert con `address` lowercase — **nessun** snapshot nome/avatar |
| **SURF-CONTACTS-008** | «Scrivi» da rubrica: `ComposeService.peerFromContact` → `ChatPeer` con `peer_address` — locale e federato |
| **SURF-CONTACTS-009** | Tap avatar contatto → [SURF-PEER-PROFILE](./SURF-PEER-PROFILE.md) — **qualsiasi** indirizzo |

### SHOULD

| ID | Promessa |
|----|----------|
| **SURF-CONTACTS-010** | UI rubrica: nome/avatar da `get_profiles`; sottotitolo = indirizzo |
| **SURF-CONTACTS-011** | Dopo aggiunta contatto: reload lista (`load()`) |

### MUST NOT

| ID | Promessa |
|----|----------|
| **SURF-CONTACTS-020** | Barra «Cerca contatto» sempre visibile (viola PROM-LIST-FILTER-031) |
| **SURF-CONTACTS-021** | Applicare PROM-LIST-FILTER al bottom sheet `_AddContactSheet` (ricerca `search_profiles` resta flusso aggiunta) |
| **SURF-CONTACTS-022** | Mostrare protocollo in inbox o come tipo chat separato |
| **SURF-CONTACTS-023** | Split `linked_profile_id` / `external_address` — un solo campo `address` |
| **SURF-CONTACTS-024** | Snapshot nome/avatar in `contacts` |
| **SURF-CONTACTS-025** | Escludere overlay peer per indirizzi `user@other-server` |

---

## 4. Tracciabilità

| SURF-ID | Verifica |
|------------------------|----------|
| SURF-CONTACTS-001–004 | `contacts_screen.dart`; `contacts_screen_test.dart`; `list_filter_test.dart` |
| SURF-CONTACTS-005 | `main.dart` — `ChangeNotifierProxyProvider` |
| SURF-CONTACTS-006 | `contact_service.dart` — `search_profiles`; `contacts_screen.dart` |
| SURF-CONTACTS-007 | `contacts_screen.dart` — insert `address` |
| SURF-CONTACTS-008 | `compose_service_test.dart` — `peerFromContact` |
| SURF-CONTACTS-011 | `contacts_controller.dart` — `addContact` → `load()` |
| SURF-CONTACTS-023, 024 | Review schema `contacts.address` |

Gate: `cd client && bash scripts/verify.sh`

---

## 5. Riferimenti

- [SYS-CONTACTS.md](../promises/system/SYS-CONTACTS.md)
- [PROM-PERSONAL-CONTACTS.md](../promises/product/PROM-PERSONAL-CONTACTS.md)
- [PROM-LIST-FILTER](../promises/product/PROM-LIST-FILTER.md)
- [SURF-PEER-PROFILE.md](./SURF-PEER-PROFILE.md)
- [registry.md](../registry.md)
