# Catalogo spec — Alfred Alpha

**Ultima revisione**: 2026-07-03  
**Metodo**: [README.md](./README.md)

Indice capability con stato e tracciabilità PR. Per contratti RPC condivisi: [contracts/rpc.md](./contracts/rpc.md).

---

## Capability (message-centric, su `main`)

| Spec ID | Titolo | Status | PR | File |
|---------|--------|--------|-----|------|
| **MSG-INBOX** | Inbox derivata da messaggi | `implemented` | #130, #134 | [MSG-INBOX.spec.md](./capabilities/MSG-INBOX.spec.md) |
| **MSG-SEND** | Invio messaggi (testo, media, location) | `implemented` | #115, #126, #153 | [MSG-SEND.spec.md](./capabilities/MSG-SEND.spec.md) |
| **AUTH-MULTI** | Multi-account client | `implemented` | #140, #147, #152 | [AUTH-MULTI.spec.md](./capabilities/AUTH-MULTI.spec.md) |

---

## Target futuro (non ancora spec capability)

| Documento | Status | Nota |
|-----------|--------|------|
| [mailbox-inbox-outbox-spec.md](../architecture/mailbox-inbox-outbox-spec.md) | Direzione `approved` | Quando su `main`, migrare a `MAILBOX-*.spec.md` e marcare MSG-INBOX message-centric come `superseded` |

---

## Mappa doc storica → spec

| Doc precedente | Spec canonica |
|----------------|---------------|
| `decisions/address-based-messaging.md` | MSG-INBOX (vincoli ADR) + MSG-SEND |
| `implementation/messages-only-inbox.md` | MSG-INBOX |
| `implementation/voice-notes.md`, `location-sharing.md` | MSG-SEND |
| `decisions/multi-account-parallel-sessions.md` | AUTH-MULTI (ADR) |
| `implementation/multi-account-client.md`, `design/auth-overlay-shell.md` | AUTH-MULTI |

---

## Prossime spec (backlog)

| ID proposto | Contenuto | Priorità |
|-------------|-----------|----------|
| MSG-READ | Spunte delivered/read (`mark_peer_read`, `server-as-reception`) | media |
| CONTACTS | Rubrica opzionale | bassa |
| PROFILE | Profilo arricchito (#134) | bassa |
| INBOX-SEARCH | Ricerca inbox on-demand (#132) | bassa |
