# SURF-INBOX — Lista conversazioni

| Campo | Valore |
|-------|--------|
| **Superficie ID** | `SURF-INBOX` |
| **Status** | `approved` |
| **Ultima revisione** | 2026-09-13 |
| **Promesse** | [PROM-LIST-FILTER](../promises/product/PROM-LIST-FILTER.md), [PROM-REALTIME-ARCHIVE](../promises/product/PROM-REALTIME-ARCHIVE.md), [PROM-CHAT-PEER-KEY](../promises/product/PROM-CHAT-PEER-KEY.md) |
| **PR** | #132, #161 |
| **Amend** | raggruppamento per `peer_address` + `get_profiles` — distillazione TEMP §7 |

Binding promessa PRODUCT filtro lista sulla inbox (`InboxPanel`) + entry «Persone consentite» in header. Inbox raggruppa per **indirizzo controparte**; presentazione via batch `get_profiles(addresses[])`.

---

## 1. Superficie

| Elemento | Valore |
|----------|--------|
| Widget | `client/lib/widgets/inbox_panel.dart` |
| Controller | `InboxController` — `filteredPeers`, `setSearchQuery` |
| Parent | `HomeScreen` — `peers: inbox.filteredPeers`, `onSearchChanged`, `key: ValueKey(accountUserId)` |
| Presentazione | `get_profiles(addresses[])` batch — fallback indirizzo grezzo |

---

## 2. Promesse SURFACE

### MUST

| ID | Promessa |
|----|----------|
| **SURF-INBOX-001** | Conforme a [PROM-LIST-FILTER](../promises/product/PROM-LIST-FILTER.md) |
| **SURF-INBOX-002** | Campi filtro: `displayName` (da `get_profiles`), `preview`, `address` (`peer_address`) del peer (`filterByQueryFields`) |
| **SURF-INBOX-003** | Hint campo e tooltip lente: «Cerca messaggi» |
| **SURF-INBOX-004** | Layout **mobile** (`showTopBar: true`): lente nell'header «Alfred», prima di Contatti; barra sotto header |
| **SURF-INBOX-005** | Layout **desktop** (`showTopBar: false`): lente nella riga «Conversazioni»; barra sotto titolo |
| **SURF-INBOX-006** | Cambio account: `ValueKey(accountUserId)` su `InboxPanel` → stato ricerca reset |
| **SURF-INBOX-007** | Icona «Persone consentite» in header inbox accanto a icona rubrica «Contatti» → naviga a `AllowedPeopleScreen` — [PROM-RECEPTION-FILTER](../promises/product/PROM-RECEPTION-FILTER.md) |
| **SURF-INBOX-008** | Header shell (`InstanceShellHeader`): se `instance.branding.wordmark_url` valorizzato, mostra immagine wordmark (altezza fissa, `BoxFit.contain`); altrimenti testo `instance.display_name`; **nessun** `logo_url` nell'header |
| **SURF-INBOX-012** | Layout **mobile** (`showTopBar: true`): trigger drawer = `ProfileAvatar` tondo dell'account in focus (non icona hamburger); tooltip «Account»; tap apre drawer sidebar |
| **SURF-INBOX-013** | Raggruppamento inbox per `peer_address` — include conversazioni federate (nessun filtro `peer_profile_id IS NOT NULL`) |
| **SURF-INBOX-014** | Tile inbox mostra indirizzo subito; arricchimento nome/avatar async via `get_profiles` |

### MUST NOT

| ID | Promessa |
|----|----------|
| **SURF-INBOX-010** | Ricerca nel contenuto messaggi chat (solo lista conversazioni) |
| **SURF-INBOX-011** | Tap su riga conversazione **non** avvia un refresh inbox bloccante che mostra `CircularProgressIndicator` al posto della lista mentre l'utente è ancora in inbox |
| **SURF-INBOX-015** | Escludere righe inbox con solo `peer_external_address` — deriva schema UUID-centrico |

---

## 4. Tracciabilità

| SURF-ID | Verifica |
|-------------------|----------|
| SURF-INBOX-001, PROM-LIST | `inbox_panel_test.dart`; `collapsible_list_search.dart`, `inbox_panel.dart` |
| SURF-INBOX-002 | `inbox_controller.dart` `filteredPeers`; `list_filter_test.dart` |
| SURF-INBOX-003 | `inbox_panel.dart` hint + tooltip |
| SURF-INBOX-004, SURF-INBOX-005 | `inbox_panel.dart` — `showTopBar` |
| SURF-INBOX-006 | `home_screen.dart` |
| SURF-INBOX-007 | `inbox_panel_test.dart`; `allowed_people_screen_test.dart` |
| SURF-INBOX-011 | `navigation_open_ingress_test.dart`; `conversation_scope_ingress_test.dart`; `inbox_panel_test.dart` |
| SURF-INBOX-012 | `inbox_panel_test.dart`; `profile_identity.dart` `AccountDrawerTrigger` |
| SURF-INBOX-013, 014 | `mailbox_inbox_smoke.sql`; scenario federato Arkham ↔ Blackgate |

---

## 5. Riferimenti

- [PROM-LIST-FILTER](../promises/product/PROM-LIST-FILTER.md)
- [PROM-CHAT-PEER-KEY](../promises/product/PROM-CHAT-PEER-KEY.md)
- [SURF-ALLOWLIST.md](./SURF-ALLOWLIST.md)
- [SURF-CHAT.md](./SURF-CHAT.md)
- [registry.md](../registry.md)
