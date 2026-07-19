# PROM-PERSONAL-CONTACTS — Rubrica isolata dalla messaggistica

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `PROM-PERSONAL-CONTACTS` |
| **Classe** | PRODUCT |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-19 |
| **PR origine** | #109 (schema + CRUD), #134 (profili in ricerca) |

Promessa di prodotto: rubrica personale come scorciatoie opzionali — **non** prerequisito per inviare/ricevere, **non** allow list di ricezione, **non** fonte inbox.

---

## 1. Problema / obiettivo

L'utente salva contatti (utenti Alfred o indirizzi federati futuri) come rubrica personale. La messaggistica resta **address-based**: si scrive sempre per indirizzo/username. La rubrica accelera «Scrivi» verso un peer noto senza alterare regole di inbox o ricezione.

Schema CRUD (`contacts`, `search_profiles`): [SYS-CONTACTS](../system/SYS-CONTACTS.md) e [contracts/schema.md](../../contracts/schema.md).

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

### MUST — compose e UX

| ID | Promessa |
|----|----------|
| **PROM-PERSONAL-CONTACTS-006** | «Scrivi» da rubrica: contatto interno → apre chat con quel peer; contatto esterno → errore «Indirizzo esterno non ancora supportato» (scope attuale) |
| **PROM-PERSONAL-CONTACTS-007** | Rubrica scoped all'account in **focus** — [PROM-MULTI-ACCOUNT](./PROM-MULTI-ACCOUNT.md) |
| **PROM-PERSONAL-CONTACTS-008** | Filtro lista: conforme a [PROM-LIST-FILTER](./PROM-LIST-FILTER.md) + [SURF-CONTACTS](../../surfaces/SURF-CONTACTS.md) |

### SHOULD

| ID | Promessa |
|----|----------|
| **PROM-PERSONAL-CONTACTS-010** | UI rubrica: sottotitolo «Utente Alfred» per internal; indirizzo esterno per federati (senza etichetta protocollo in inbox) |
| **PROM-PERSONAL-CONTACTS-011** | Dopo aggiunta contatto: reload lista |

### MUST NOT

| ID | Promessa |
|----|----------|
| **PROM-PERSONAL-CONTACTS-020** | Mostrare protocollo in inbox o come tipo chat separato |
| **PROM-PERSONAL-CONTACTS-021** | Messaggistica verso esterni da rubrica (scope attuale) (solo salvataggio rubrica) |
| **PROM-PERSONAL-CONTACTS-022** | Confondere rubrica (scorciatoia) con allow list (ricezione) |

---


## 3. Modello (riferimento)

| Elemento | Artefatto |
|----------|-----------|
| Glossario / comandi | [docs/domain/contacts/](../../../domain/contacts/) |
| UML | [docs/model/uml/contacts/](../../model/uml/contacts/) — [seq-compose-from-contact.puml](../../model/uml/contacts/seq-compose-from-contact.puml) |
| Statechart client | [client/lib/machines/contacts/](../../../client/lib/machines/contacts/) |
| Compose da rubrica | `StartChatFromContact` → `OpenFromCompose` (navigation) |

**Implementazione (non vincolante):** [docs/domain/contacts/README.md](../../../domain/contacts/README.md) · schema: [SYS-CONTACTS](../system/SYS-CONTACTS.md)


## 4. Superfici conformi

| Superficie | Stato | File |
|------------|-------|------|
| SURF-CONTACTS | `implemented` | [SURF-CONTACTS.md](../../surfaces/SURF-CONTACTS.md) |
| Compose da rubrica | `implemented` | `contacts_screen.dart`, `compose_service.dart` |

---

## 5. Tracciabilità

| PROM-ID | Verifica |
|---------|----------|
| PROM-PERSONAL-CONTACTS-006 | `compose_service_test.dart` — `peerFromContact` internal/external |
| PROM-PERSONAL-CONTACTS-007 | `main.dart` — `ChangeNotifierProxyProvider<AuthController, ContactsController?>` |
| PROM-PERSONAL-CONTACTS-008 | `list_filter_test.dart`; `contacts_screen_test.dart` |
| PROM-PERSONAL-CONTACTS-003, PROM-PERSONAL-CONTACTS-004 | `send_message_to_profile_smoke.sql`; `SYS-MAILBOX-045` |
| PROM-PERSONAL-CONTACTS-021 | `compose_service.dart` — errore contatto esterno |
| PROM-PERSONAL-CONTACTS-011 | `contacts_controller.dart` — `addInternal` / `addExternal` → `load()` |


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
