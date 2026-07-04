# Catalogo spec — Alfred (prototipo)

**Ultima revisione**: 2026-07-04  
**REQ-ID**: tutte le capability Alpha elencate sotto sono `implemented` su `main`.

Indice capability con stato e tracciabilità PR. Contratti: [rpc.md](./contracts/rpc.md), [schema.md](./contracts/schema.md).

**SDD v1**: REQ-ID + tracciabilità su tutte le capability Alpha. Metodo: [README.md](./README.md).

---

## Capability mailbox (modello caselle)

| Spec ID | Titolo | Status | PR | File |
|---------|--------|--------|-----|------|
| **MAILBOX-CORE** | Archivio per owner, identificatori, migrazione | `implemented` | #159 | [MAILBOX-CORE.spec.md](./capabilities/MAILBOX-CORE.spec.md) |
| **MAILBOX-SEND** | Invio e outbox sempre | `implemented` | #159 | [MAILBOX-SEND.spec.md](./capabilities/MAILBOX-SEND.spec.md) |
| **MAILBOX-INBOX** | Inbox da archivio owner | `implemented` | #159 | [MAILBOX-INBOX.spec.md](./capabilities/MAILBOX-INBOX.spec.md) |
| **MAILBOX-READ** | Date consegna e lettura | `implemented` | #159 | [MAILBOX-READ.spec.md](./capabilities/MAILBOX-READ.spec.md) |

---

## Altre capability

| Spec ID | Titolo | Status | PR | File |
|---------|--------|--------|-----|------|
| **INBOX-SEARCH** | Ricerca on-demand inbox | `implemented` | #132 | [INBOX-SEARCH.spec.md](./capabilities/INBOX-SEARCH.spec.md) |
| **PROFILE** | Profilo utente (avatar, pronomi) | `implemented` | #118, #134 | [PROFILE.spec.md](./capabilities/PROFILE.spec.md) |
| **CONTACTS** | Rubrica personale | `implemented` | #109 | [CONTACTS.spec.md](./capabilities/CONTACTS.spec.md) |
| **AUTH-MULTI** | Multi-account client | `implemented` | #140, #147, #152 | [AUTH-MULTI.spec.md](./capabilities/AUTH-MULTI.spec.md) |

---

## Mappa doc → spec

| Doc | Spec canonica |
|-----|---------------|
| `decisions/address-based-messaging.md` | MAILBOX-INBOX + MAILBOX-SEND + CONTACTS (ADR indirizzo/rubrica) |
| `implementation/voice-notes.md`, `location-sharing.md` | MAILBOX-SEND |
| `decisions/server-as-reception.md` | MAILBOX-READ (ADR) |
| `decisions/multi-account-parallel-sessions.md` | AUTH-MULTI (ADR) |
| `implementation/multi-account-client.md`, `design/auth-overlay-shell.md` | AUTH-MULTI |
| `design/inbox-search-toggle.md` | INBOX-SEARCH |
| `PROJECT_MAP.md` § profilo | PROFILE |
| `architecture/mailbox-inbox-outbox-spec.md` | MAILBOX-CORE, MAILBOX-SEND, MAILBOX-INBOX, MAILBOX-READ |

---

## Prossime spec (backlog)

| ID proposto | Contenuto | Priorità |
|-------------|-----------|----------|
| BRIDGE-* | Consumer outbox federato (fase B post-mailbox) | backlog |
