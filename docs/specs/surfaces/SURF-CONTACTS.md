# SURF-CONTACTS — Rubrica

| Campo | Valore |
|-------|--------|
| **Superficie ID** | `SURF-CONTACTS` |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-08 |
| **Promesse** | [PROM-LIST-FILTER](../promises/product/PROM-LIST-FILTER.md), [SYS-CONTACTS](../promises/system/SYS-CONTACTS.md) |
| **PR** | #109, #134 |

Binding completo schermata Contatti: filtro lista, aggiunta Alfred/esterno, compose, controller per account in focus.

---

## 1. Superficie

| Elemento | Valore |
|----------|--------|
| Schermata | `client/lib/screens/contacts_screen.dart` |
| Controller | `ContactsController` — `filteredContacts`, `setSearchQuery`, `ownerId` = focus |
| Servizi | `ContactService`, `ComposeService.peerFromContact` |
| Sheet | `_AddContactSheet` — tab Alfred / Esterno |

---

## 2. Promesse SURFACE

### MUST — filtro lista

| ID | Promessa |
|----|----------|
| **SURF-CONTACTS-001** | Conforme a [PROM-LIST-FILTER](../promises/product/PROM-LIST-FILTER.md) |
| **SURF-CONTACTS-002** | Campo filtro: `display_name` del contatto (`filterByQuery` su `displayName`) |
| **SURF-CONTACTS-003** | Hint campo e tooltip lente: «Cerca contatto» |
| **SURF-CONTACTS-004** | Lente nell'`AppBar` (accanto ad azione aggiungi); barra sotto AppBar solo se aperta |

### MUST — rubrica e compose

| ID | Promessa |
|----|----------|
| **SURF-CONTACTS-005** | `ContactsController` legato all'account in **focus** (`ChangeNotifierProxyProvider` + `ownerId`) |
| **SURF-CONTACTS-006** | Aggiunta internal: `search_profiles` (min 2 caratteri) → selezione → insert `protocol=internal` |
| **SURF-CONTACTS-007** | Aggiunta esterna: form manuale (protocollo XMPP/Matrix, nome, JID/ID) → insert external |
| **SURF-CONTACTS-008** | «Scrivi» da rubrica (icona chat): **Internal** → `ComposeService.peerFromContact` → `ChatPeer`; **Esterno** → errore «Indirizzo esterno non ancora supportato» (Alpha) |
| **SURF-CONTACTS-009** | Tap avatar contatto **internal** → [SURF-PEER-PROFILE](./SURF-PEER-PROFILE.md) |

### SHOULD

| ID | Promessa |
|----|----------|
| **SURF-CONTACTS-010** | UI rubrica: sottotitolo «Utente Alfred» per internal; indirizzo esterno per federati |
| **SURF-CONTACTS-011** | Dopo aggiunta contatto: reload lista (`load()`) |

### MUST NOT

| ID | Promessa |
|----|----------|
| **SURF-CONTACTS-020** | Barra «Cerca contatto» sempre visibile (viola PROM-LIST-FILTER-031) |
| **SURF-CONTACTS-021** | Applicare PROM-LIST-FILTER al bottom sheet `_AddContactSheet` (ricerca `search_profiles` resta flusso aggiunta) |
| **SURF-CONTACTS-022** | Mostrare protocollo in inbox o come tipo chat separato |
| **SURF-CONTACTS-023** | Messaggistica verso esterni da rubrica in Alpha (solo salvataggio rubrica) |
| **SURF-CONTACTS-024** | Overlay peer per contatti rubrica **esterni** (senza `linked_profile_id`) |

---

## 4. Tracciabilità

| SURF-ID | Verifica |
|------------------------|----------|
| SURF-CONTACTS-001–004 | `contacts_screen.dart`; `contacts_screen_test.dart`; `list_filter_test.dart` |
| SURF-CONTACTS-005 | `main.dart` — `ChangeNotifierProxyProvider` |
| SURF-CONTACTS-006 | `contact_service.dart` — `search_profiles`; `contacts_screen.dart` |
| SURF-CONTACTS-007 | `contacts_screen.dart` — tab Esterno + `addExternal` |
| SURF-CONTACTS-008 | `compose_service_test.dart` — `peerFromContact` |
| SURF-CONTACTS-011 | `contacts_controller.dart` — `addInternal` / `addExternal` → `load()` |
| SURF-CONTACTS-023 | `compose_service.dart` — errore esterno Alpha |

Gate: `cd client && bash scripts/verify.sh`

---

## 5. Riferimenti

- [SYS-CONTACTS.md](../promises/system/SYS-CONTACTS.md)
- [PROM-LIST-FILTER](../promises/product/PROM-LIST-FILTER.md)
- [SURF-PEER-PROFILE.md](./SURF-PEER-PROFILE.md)
- [registry.md](../registry.md)
