# SYS-CONTACTS — Rubrica personale (piattaforma)

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `SYS-CONTACTS` |
| **Classe** | SYSTEM |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-08 |
| **Contratti** | [schema.md](../../contracts/schema.md) · [rpc.md](../../contracts/rpc.md) |
| **PR** | #109, #134 |

Promesse di piattaforma per tabella `contacts`, RLS, unicità e RPC `search_profiles` — rubrica isolata dalla messaggistica e dall'allow list.

---

## 1. Problema / obiettivo

L'utente può salvare contatti (utenti Alfred interni o indirizzi federati futuri) come rubrica personale scoped per owner. Il backend garantisce schema, CRUD PostgREST e ricerca profili per aggiunta — senza legare rubrica a invio o inbox.

---

## 2. Promesse SYSTEM

### MUST

| ID | Promessa |
|----|----------|
| **SYS-CONTACTS-001** | Tabella `contacts` scoped per owner: `owner_id = auth.uid()` (RLS) |
| **SYS-CONTACTS-002** | Tipi contatto (`contact_protocol`): `internal`, `xmpp`, `matrix` — solo routing backend |
| **SYS-CONTACTS-003** | **Internal**: `linked_profile_id` obbligatorio, `external_address` null; `display_name` + `avatar_url` opzionale (snapshot al momento dell'aggiunta) |
| **SYS-CONTACTS-004** | **Esterno** (xmpp/matrix): `external_address` obbligatorio, `linked_profile_id` null; `display_name` obbligatorio |
| **SYS-CONTACTS-005** | Unicità: `(owner_id, linked_profile_id)` per internal; `(owner_id, lower(external_address))` per esterni |
| **SYS-CONTACTS-006** | CRUD via PostgREST diretto su `contacts` (nessuna RPC dedicata add/delete) |
| **SYS-CONTACTS-007** | Lista contatti: ordinata per `display_name` (client `ContactService.fetchContacts`) |
| **SYS-CONTACTS-008** | Ricerca utenti Alfred per aggiunta: RPC `search_profiles(p_query, p_limit)` — min **2** caratteri lato client; max 50 server-side |

### MUST NOT

| ID | Promessa |
|----|----------|
| **SYS-CONTACTS-016** | Prerequisito `contact_id` per inviare messaggi a utenti Alfred |
| **SYS-CONTACTS-017** | Creare conversazione/thread al salvataggio contatto |
| **SYS-CONTACTS-018** | Usare `contacts` come fonte di verità inbox (inbox deriva da `messages` only) |
| **SYS-CONTACTS-019** | `contacts` come fonte o proxy dell'allow list di ricezione |

---

## 3. Contratto

| Elemento | Comportamento |
|----------|---------------|
| `contacts` | Colonne: `id`, `owner_id`, `protocol`, `linked_profile_id`, `external_address`, `display_name`, `avatar_url`, timestamps |
| RLS | SELECT/INSERT/UPDATE/DELETE solo `owner_id = auth.uid()` |
| `search_profiles(text, int)` | Cerca `username` o `display_name` ILIKE; esclude self; ritorna `id`, `username`, `display_name`, `avatar_url` |

Migrazione base: `20260624200000_alfred_domain_schema.sql`.

---

## 5. Tracciabilità

| SYS-ID | Verifica |
|-----------------------|----------|
| SYS-CONTACTS-001 | `schema_smoke.sql` — tabella `contacts`; `20260624200000_alfred_domain_schema.sql` |
| SYS-CONTACTS-002 | `models_and_utils_test.dart` — `ContactProtocol` parsing |
| SYS-CONTACTS-006 | `contact_service.dart` — PostgREST fetch/insert/delete |
| SYS-CONTACTS-008 | `contact_service.dart` — `search_profiles`; `contacts_screen.dart` — min 2 caratteri |
| SYS-CONTACTS-016 | `send_message_to_profile_smoke.sql` — invio senza contatto in rubrica |
| SYS-CONTACTS-018 | `SYS-MAILBOX-045` |

Gate: `bash scripts/check-spec-sync.sh` · `cd client && bash scripts/verify.sh`

---

## 6. Riferimenti

- [registry.md](../../registry.md)
- [SURF-CONTACTS.md](../../surfaces/SURF-CONTACTS.md) — schermata rubrica
- [SYS-RECEPTION.md](./SYS-RECEPTION.md) — allow list isolata
- [contracts/schema.md](../../contracts/schema.md) · [contracts/rpc.md](../../contracts/rpc.md)
