# SYS-CONTACTS — Rubrica personale (piattaforma)

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `SYS-CONTACTS` |
| **Classe** | SYSTEM |
| **Status** | `approved` — amend §7 contacts.address only (implementazione pendente) |
| **Ultima revisione** | 2026-09-13 |
| **Contratti** | [schema.md](../../contracts/schema.md) · [rpc.md](../../contracts/rpc.md) |
| **PR** | #109, #134 |

Promesse di piattaforma per tabella `contacts`, RLS, unicità e RPC `search_profiles` — rubrica isolata dalla messaggistica e dall'allow list.

---

## 1. Problema / obiettivo

L'utente può salvare contatti come rubrica personale scoped per titolare archivio — **solo indirizzo** (`username` o `user@server`, lowercase). Presentazione nome/avatar via `get_profiles` — **non** snapshot in `contacts`.

---

## 2. Promesse SYSTEM

### MUST

| ID | Promessa |
|----|----------|
| **SYS-CONTACTS-001** | Tabella `contacts` scoped per titolare archivio: `archive_user_id = auth.uid()` (RLS) |
| **SYS-CONTACTS-002** | Colonna **`address`** text NOT NULL — unico dato identità contatto (lowercase) |
| **SYS-CONTACTS-003** | Unicità `(archive_user_id, address)` |
| **SYS-CONTACTS-004** | **MUST NOT** colonne `linked_profile_id`, `external_address`, `display_name`, `avatar_url` — deriva rimossa |
| **SYS-CONTACTS-005** | Input case insensitive; persistenza **sempre lowercase** |
| **SYS-CONTACTS-006** | CRUD via PostgREST diretto su `contacts` (nessuna RPC dedicata add/delete) |
| **SYS-CONTACTS-007** | Lista contatti: ordinata per `address` (client); display via `get_profiles` batch |
| **SYS-CONTACTS-008** | Ricerca utenti Alfred per aggiunta: RPC `search_profiles` → salvare **`username`** come `contacts.address` |
| **SYS-CONTACTS-009** | Aggiunta contatto federato: salvare `user@server` come `address` — stesso schema locale/federato |

### MUST NOT

| ID | Promessa |
|----|----------|
| **SYS-CONTACTS-016** | Prerequisito `contact_id` per inviare messaggi a utenti Alfred |
| **SYS-CONTACTS-017** | Creare conversazione/thread al salvataggio contatto |
| **SYS-CONTACTS-018** | Usare `contacts` come fonte di verità inbox (inbox deriva da `messages` only) |
| **SYS-CONTACTS-020** | Rubrica come cache profilo (snapshot nome/avatar) — presentazione solo via `get_profiles` |

---

## 3. Contratto

| Elemento | Comportamento |
|----------|---------------|
| `contacts` | Colonne: `id`, `archive_user_id`, **`address`** text NOT NULL, timestamps |
| RLS | SELECT/INSERT/UPDATE/DELETE solo `archive_user_id = auth.uid()` |
| `search_profiles(text, int)` | Cerca profili locali; client salva `username` come `address` |
| `get_profiles(text[])` | Presentazione batch — vedi [SYS-PROFILE](./SYS-PROFILE.md) |

Migrazione base: `20260624200000_alfred_domain_schema.sql`.

---

## 5. Tracciabilità

| SYS-ID | Verifica |
|-----------------------|----------|
| SYS-CONTACTS-001 | `schema_smoke.sql` — tabella `contacts`; `20260624200000_alfred_domain_schema.sql` |
| SYS-CONTACTS-002 | `models_and_utils_test.dart` — flag `isLocal` / `isFederated` |
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
