# PROM-PERSONAL-CONTACTS — Rubrica isolata dalla messaggistica

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `PROM-PERSONAL-CONTACTS` |
| **Classe** | PRODUCT |
| **Status** | `approved` |
| **Ultima revisione** | 2026-09-13 |
| **PR origine** | #109 (schema + CRUD), #134 (profili in ricerca) |
| **Amend** | rubrica solo `address` — distillazione [TEMP-chat-peer-key-address-drift.md](../../../tmp/TEMP-chat-peer-key-address-drift.md) §7 |

Promessa di prodotto: rubrica personale come scorciatoie opzionali — **non** prerequisito per inviare/ricevere, **non** allow list di ricezione, **non** fonte inbox. **`contacts` salva soltanto `address` lowercase** — non nome, avatar, né `linked_profile_id`. Presentazione via `get_profiles(addresses[])`.

---

## 1. Problema / obiettivo

L'utente salva indirizzi (`username` bare o `user@server`) come rubrica personale. La messaggistica resta **address-based**: si scrive sempre per indirizzo. La rubrica accelera «Scrivi» verso un peer noto senza alterare regole di inbox o ricezione.

Schema CRUD target (`contacts.address`, `search_profiles` per aggiunta): [SYS-CONTACTS](../system/SYS-CONTACTS.md) (amend) e [contracts/schema.md](../../contracts/schema.md).

---

## 2. Promesse

### MUST — isolamento

| ID | Promessa |
|----|----------|
| **PROM-PERSONAL-CONTACTS-001** | Rubrica **non** abilita né blocca l'invio messaggi — invio sempre per indirizzo peer |
| **PROM-PERSONAL-CONTACTS-002** | Rubrica **non** è l'allow list di ricezione — vedi [PROM-RECEPTION-FILTER](./PROM-RECEPTION-FILTER.md) |
| **PROM-PERSONAL-CONTACTS-003** | `contacts` **non** è fonte di verità inbox — inbox deriva solo da `messages` |
| **PROM-PERSONAL-CONTACTS-004** | Nessun `contact_id` richiesto per inviare messaggi a utenti Alfred |
| **PROM-PERSONAL-CONTACTS-005** | Salvataggio contatto **non** crea conversazione/thread in inbox |
| **PROM-PERSONAL-CONTACTS-009** | `contacts` salva **solo** `address` text lowercase — UNIQUE `(archive_user_id, address)` |

### MUST — compose e UX

| ID | Promessa |
|----|----------|
| **PROM-PERSONAL-CONTACTS-006** | «Scrivi» da rubrica: apre chat con `peer_address` del contatto — stessa UI locale e federata |
| **PROM-PERSONAL-CONTACTS-007** | Rubrica scoped all'account in **focus** — [PROM-MULTI-ACCOUNT](./PROM-MULTI-ACCOUNT.md) |
| **PROM-PERSONAL-CONTACTS-008** | Filtro lista: conforme a [PROM-LIST-FILTER](./PROM-LIST-FILTER.md) + [SURF-CONTACTS](../../surfaces/SURF-CONTACTS.md) — campi filtro da `get_profiles` + `address` |
| **PROM-PERSONAL-CONTACTS-012** | Presentazione contatti: batch `get_profiles(addresses[])` — fallback indirizzo grezzo |

### SHOULD

| ID | Promessa |
|----|----------|
| **PROM-PERSONAL-CONTACTS-010** | UI rubrica: nome/avatar da `get_profiles`; sottotitolo = indirizzo |
| **PROM-PERSONAL-CONTACTS-011** | Dopo aggiunta contatto: reload lista |

### MUST NOT

| ID | Promessa |
|----|----------|
| **PROM-PERSONAL-CONTACTS-020** | Mostrare protocollo in inbox o come tipo chat separato |
| **PROM-PERSONAL-CONTACTS-021** | Snapshot nome/avatar in `contacts` — rubrica **non** è cache profilo |
| **PROM-PERSONAL-CONTACTS-022** | Confondere rubrica (scorciatoia) con allow list (ricezione) |
| **PROM-PERSONAL-CONTACTS-023** | Split `linked_profile_id` / `external_address` — un solo campo `address` |
| **PROM-PERSONAL-CONTACTS-024** | Escludere contatti `user@other-server` dalla rubrica |

---

## 3. Modello (riferimento)

| Elemento | Artefatto |
|----------|-----------|
| Glossario / comandi | [docs/domain/contacts/](../../../domain/contacts/) |
| UML | [docs/model/uml/contacts/](../../../model/uml/contacts/) — [seq-compose-from-contact.puml](../../../model/uml/contacts/seq-compose-from-contact.puml) |
| Statechart client | [client/lib/machines/contacts/](../../../../client/lib/machines/contacts/) |
| Compose da rubrica | `StartChatFromContact` → `OpenPeerOnFocusedAccount` (navigation) |

**Implementazione (non vincolante):** [docs/domain/contacts/README.md](../../../domain/contacts/README.md) · schema: [SYS-CONTACTS](../system/SYS-CONTACTS.md)

---

## 4. Superfici conformi

| Superficie | Stato | File |
|------------|-------|------|
| SURF-CONTACTS | `approved` | [SURF-CONTACTS.md](../../surfaces/SURF-CONTACTS.md) |
| Compose da rubrica | `approved` | `contacts_screen.dart`, `compose_service.dart` |

---

## 5. Tracciabilità

| PROM-ID | Verifica |
|---------|----------|
| PROM-PERSONAL-CONTACTS-006 | `compose_service_test.dart` — `peerFromContact` con `address` |
| PROM-PERSONAL-CONTACTS-007 | `main.dart` — `ChangeNotifierProxyProvider<AuthController, ContactsController?>` |
| PROM-PERSONAL-CONTACTS-008 | `list_filter_test.dart`; `contacts_screen_test.dart` |
| PROM-PERSONAL-CONTACTS-003, PROM-PERSONAL-CONTACTS-004 | `send_message_to_profile_smoke.sql`; `SYS-MAILBOX-045` |
| PROM-PERSONAL-CONTACTS-009, 021, 023 | Review schema `contacts.address` |
| PROM-PERSONAL-CONTACTS-012 | `get_profiles` batch in lista contatti |
| PROM-PERSONAL-CONTACTS-011 | `contacts_controller.dart` — `addContact` → `load()` |

Gate: `bash scripts/check-spec-sync.sh` + `cd client && bash scripts/verify.sh`

---

## 6. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [registry.md](../../registry.md) | Indice promesse |
| [SYS-CONTACTS](../system/SYS-CONTACTS.md) | Schema e CRUD backend |
| [SURF-CONTACTS](../../surfaces/SURF-CONTACTS.md) | Binding superficie |
| [PROM-RECEPTION-FILTER](./PROM-RECEPTION-FILTER.md) | Allow list separata |
| [PROM-PEER-PROFILE](./PROM-PEER-PROFILE.md) | Azione rubrica da overlay peer |
| [address-based-messaging.md](../../../decisions/address-based-messaging.md) | ADR |
