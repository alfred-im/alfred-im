# CONTACTS — Rubrica personale

| Campo | Valore |
|-------|--------|
| **Spec ID** | `CONTACTS` |
| **Layer** | capability |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-03 |
| **ADR** | [address-based-messaging.md](../../decisions/address-based-messaging.md), [no-internal-external-chat-distinction.md](../../decisions/no-internal-external-chat-distinction.md) |
| **PR** | #109 (schema + CRUD), #134 (profili in ricerca) |
| **Correlata** | [MAILBOX-INBOX](./MAILBOX-INBOX.spec.md), [PROFILE](./PROFILE.spec.md), [AUTH-MULTI](./AUTH-MULTI.spec.md) |

Documento per AI — contratto rubrica opzionale: scorciatoie personali, **isolata** dalla messaggistica.

---

## 1. Problema / obiettivo

L’utente può salvare contatti (utenti Alfred interni o indirizzi federati futuri) come rubrica personale. La rubrica **non** abilita né blocca l’invio messaggi: si scrive sempre per indirizzo ([MAILBOX-INBOX](./MAILBOX-INBOX.spec.md)). «Scrivi» da rubrica apre la chat come scorciatoia verso `profile_id` o indirizzo esterno.

---

## 2. Requisiti

### MUST

| ID | Requisito |
|----|-----------|
| **CONTACTS-REQ-001** | Tabella `contacts` scoped per owner: `owner_id = auth.uid()` (RLS) |
| **CONTACTS-REQ-002** | Tipi contatto (`contact_protocol`): `internal`, `xmpp`, `matrix` — solo routing backend; **nessuna** tipologia chat distinta in UI ([no-internal-external-chat-distinction](../../decisions/no-internal-external-chat-distinction.md)) |
| **CONTACTS-REQ-003** | **Internal**: `linked_profile_id` obbligatorio, `external_address` null; `display_name` + `avatar_url` opzionale (snapshot al momento dell’aggiunta) |
| **CONTACTS-REQ-004** | **Esterno** (xmpp/matrix): `external_address` obbligatorio, `linked_profile_id` null; `display_name` obbligatorio |
| **CONTACTS-REQ-005** | Unicità: `(owner_id, linked_profile_id)` per internal; `(owner_id, lower(external_address))` per esterni |
| **CONTACTS-REQ-006** | CRUD via PostgREST diretto su `contacts` (nessuna RPC dedicata add/delete) |
| **CONTACTS-REQ-007** | Lista contatti: `ContactService.fetchContacts(ownerId)` ordinata per `display_name` |
| **CONTACTS-REQ-008** | Ricerca utenti Alfred per aggiunta: RPC `search_profiles(p_query, p_limit)` — min **2** caratteri lato client; max 50 server-side |
| **CONTACTS-REQ-009** | Aggiunta internal: `search_profiles` → selezione → `insert` con `protocol=internal` |
| **CONTACTS-REQ-010** | Aggiunta esterna: form manuale (protocollo, nome, JID/ID Matrix) → `insert` |
| **CONTACTS-REQ-011** | «Scrivi» da rubrica (icona chat): **Internal** → `ComposeService.peerFromContact` → `ChatPeer`; **Esterno** → errore «Indirizzo esterno non ancora supportato» (Alpha) |
| **CONTACTS-REQ-012** | `ContactsController` legato all’account in **focus** (`ChangeNotifierProxyProvider` + `ownerId`) — [AUTH-MULTI](./AUTH-MULTI.spec.md) |
| **CONTACTS-REQ-013** | Filtro lista: client-side su `display_name` (`filteredContacts`) |

### SHOULD

| ID | Requisito |
|----|-----------|
| **CONTACTS-REQ-014** | UI rubrica: sottotitolo «Utente Alfred» per internal; indirizzo esterno per federati (senza etichetta protocollo in inbox) |
| **CONTACTS-REQ-015** | Dopo aggiunta contatto: reload lista |

### MUST NOT

| ID | Requisito |
|----|-----------|
| **CONTACTS-REQ-016** | Prerequisito `contact_id` per inviare messaggi a utenti Alfred |
| **CONTACTS-REQ-017** | Creare conversazione/thread al salvataggio contatto |
| **CONTACTS-REQ-018** | Mostrare protocollo in inbox o come tipo chat separato |
| **CONTACTS-REQ-019** | `contacts` come fonte di verità inbox (inbox deriva da `messages` only) — [MAILBOX-INBOX](./MAILBOX-INBOX.spec.md) |
| **CONTACTS-REQ-020** | Messaggistica verso esterni da rubrica in Alpha (solo salvataggio rubrica) |

---

## 3. Fuori scope

- Eliminazione contatto da UI (API `deleteContact` esiste, non esposta in `ContactsScreen` Alpha).
- Sincronizzazione automatica `display_name`/`avatar_url` contatto quando il peer aggiorna profilo.
- Import/export rubrica.
- Invio/ricezione federata (bridge stub).

---

## 4. Contratto

### 4.1 Backend

| Elemento | Comportamento |
|----------|---------------|
| `contacts` | Colonne: `id`, `owner_id`, `protocol`, `linked_profile_id`, `external_address`, `display_name`, `avatar_url`, timestamps |
| RLS | SELECT/INSERT/UPDATE/DELETE solo `owner_id = auth.uid()` |
| `search_profiles(text, int)` | Cerca `username` o `display_name` ILIKE; esclude self; ritorna `id`, `username`, `display_name`, `avatar_url` |

Migrazione base: `20260624200000_alfred_domain_schema.sql`.

### 4.2 Client

| Componente | Responsabilità |
|------------|----------------|
| `Contact` / `ContactProtocol` | Modello rubrica |
| `ContactService` | fetch, search, add internal/external, delete |
| `ContactsController` | Stato lista, filtro, delega add/search |
| `ContactsScreen` | Lista + ricerca + sheet aggiunta (tab Alfred / Esterno) |
| `ComposeService.peerFromContact` | Contatto internal → `ChatPeer`; esterno → errore Alpha |

### 4.3 UX aggiunta contatto

| Tab | Flusso |
|-----|--------|
| **Alfred** | Campo ricerca → `search_profiles` → tap risultato → insert internal |
| **Esterno** | Dropdown XMPP/Matrix + nome + indirizzo → insert external |

### 4.4 Relazione con messaggistica

| Azione | Rubrica richiesta? |
|--------|-------------------|
| FAB nuova chat per username | No |
| Messaggio ricevuto da sconosciuto | No (compare in inbox) |
| Tap «Scrivi» in rubrica | Scorciatoia — apre chat esistente/vuota per quel peer |

---

## 5. Tracciabilità

| REQ-ID | Verifica |
|--------|----------|
| CONTACTS-REQ-001, REQ-005 | `schema_smoke.sql` — tabella `contacts`; migrazione `20260624200000_alfred_domain_schema.sql` |
| CONTACTS-REQ-002 | `models_and_utils_test.dart` — `ContactProtocol` parsing |
| CONTACTS-REQ-006, REQ-007 | `contact_service.dart` — PostgREST fetch/insert/delete |
| CONTACTS-REQ-008, REQ-009 | `contact_service.dart` — `search_profiles`; `contacts_screen.dart` — min 2 caratteri |
| CONTACTS-REQ-010 | `contacts_screen.dart` — tab Esterno + `addExternal` |
| CONTACTS-REQ-011 | `compose_service_test.dart` — `peerFromContact` internal/external |
| CONTACTS-REQ-012 | `main.dart` — `ChangeNotifierProxyProvider<AuthController, ContactsController?>` |
| CONTACTS-REQ-013 | `list_filter_test.dart` — `filterByQuery`; `contacts_controller.dart` `filteredContacts` |
| CONTACTS-REQ-015 | `contacts_controller.dart` — `addInternal` / `addExternal` → `load()` |
| CONTACTS-REQ-016, REQ-019 | `send_message_to_profile_smoke.sql` — invio senza contatto in rubrica; `MAILBOX-INBOX-REQ-018` |
| CONTACTS-REQ-020 | `compose_service.dart` — `peerFromContact` errore esterno Alpha |

Gate: `cd client && bash scripts/verify.sh` · Manuale: aggiungi contatto Alfred; «Scrivi»; aggiungi XMPP in rubrica (no chat federata)

---

## 6. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [address-based-messaging.md](../../decisions/address-based-messaging.md) | Rubrica isolata da chat |
| [alpha-full-stack.md](../../architecture/alpha-full-stack.md) §7 | Limitazioni federato |
| [PROFILE](./PROFILE.spec.md) | `search_profiles`, `ProfileSummary` |

**Codice**: `client/lib/services/contact_service.dart`, `providers/contacts_controller.dart`, `screens/contacts_screen.dart`, `services/compose_service.dart`
