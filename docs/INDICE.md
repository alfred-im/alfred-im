# Indice Documentazione (Riferimento AI)

Indice documenti tecnici per navigazione rapida. Documento per AI, non per utenti.

## Client attivo

- **Live**: https://alfred-im.github.io/XmppTest/
- **Codice**: `client/` (Flutter + Supabase)

---

## Spec (SDD v2) — registro promesse

**Metodo**: [specs/README.md](./specs/README.md) · **Registro**: [specs/registry.md](./specs/registry.md) · **Capability legacy**: [specs/index.md](./specs/index.md)

### Promesse PRODUCT / SURFACE (v2)

| ID | Stato | Contenuto |
|----|-------|-----------|
| [PROM-LIST-FILTER](./specs/promises/product/PROM-LIST-FILTER.md) | `implemented` | Filtro locale + ricerca on-demand (lente) |
| [SURF-INBOX](./specs/surfaces/SURF-INBOX.md) | `implemented` | Lista conversazioni |
| [SURF-CONTACTS](./specs/surfaces/SURF-CONTACTS.md) | `implemented` | Rubrica — filtro lista on-demand |
| [SURF-ALLOWLIST](./specs/surfaces/SURF-ALLOWLIST.md) | `implemented` | Persone consentite — filtro lista on-demand |

### SYSTEM + capability legacy

| Spec | Stato | Contenuto |
|------|-------|-----------|
| [MAILBOX-CORE](./specs/capabilities/MAILBOX-CORE.spec.md) | `implemented` | Archivio per owner, outbox sempre, `logical_message_id` |
| [MAILBOX-INBOX](./specs/capabilities/MAILBOX-INBOX.spec.md) | `implemented` | Inbox on-read sul mio archivio, `ChatPeer`, realtime |
| [MAILBOX-SEND](./specs/capabilities/MAILBOX-SEND.spec.md) | `implemented` | Invio testo/GIF/voice/location, pipeline outbox |
| [MAILBOX-READ](./specs/capabilities/MAILBOX-READ.spec.md) | `implemented` | Spunte `delivered_at`/`read_at`, `mark_peer_read` |
| [INBOX-SEARCH](./specs/capabilities/INBOX-SEARCH.spec.md) | `superseded` | UX → PROM-LIST-FILTER + SURF-INBOX |
| [PROFILE](./specs/capabilities/PROFILE.spec.md) | `implemented` | Profilo, avatar, pronomi, `ProfileSummary` |
| [CONTACTS](./specs/capabilities/CONTACTS.spec.md) | `implemented` | Rubrica personale (isolata da chat) |
| [AUTH-MULTI](./specs/capabilities/AUTH-MULTI.spec.md) | `implemented` | Multi-account, focus, overlay shell |
| [RECEPTION-ALLOWLIST](./specs/capabilities/RECEPTION-ALLOWLIST.spec.md) | `implemented` | Allow list ricezione, gate server, UI «Persone consentite» |
| [GROUP-CORE](./specs/capabilities/GROUP-CORE.spec.md) | `implemented` | Account gruppo, shell, partecipazione allow list |
| [GROUP-DELIVERY](./specs/capabilities/GROUP-DELIVERY.spec.md) | `implemented` | Invio, erogazione, autori, broadcast |
| [PEER-PROFILE](./specs/capabilities/PEER-PROFILE.spec.md) | `implemented` | Scheda profilo peer (tap avatar), Allow + rubrica |
| [contracts/rpc.md](./specs/contracts/rpc.md) | `implemented` | Firme RPC messaggistica |
| [contracts/schema.md](./specs/contracts/schema.md) | `implemented` | Schema DB, enum, RLS, storage |

ADR e panoramica: [architecture/mailbox-inbox-outbox-spec.md](./architecture/mailbox-inbox-outbox-spec.md) (PR #159).

---

## Documenti root

- **[.cursor/rules/main.mdc](../.cursor/rules/main.mdc)** — Vincolo Cursor → `.cursor-rules.md`
- **[PROJECT_MAP.md](../PROJECT_MAP.md)** — **Leggere all'inizio di ogni sessione**
- **[README.md](../README.md)** — Stato progetto
- **[CHANGELOG.md](../CHANGELOG.md)** — Storia modifiche Alpha
- **[.cursor-rules.md](../.cursor-rules.md)** — Regole sviluppo AI
- **[AGENTS.md](../AGENTS.md)** — Toolchain Cloud Agent
- **[AGENT_DEBUG_ACCOUNTS.md](./AGENT_DEBUG_ACCOUNTS.md)** — **Account Supabase solo agente** + regola non toccare test1/2/3
- **[SESSION_HANDOFF.md](./SESSION_HANDOFF.md)** — **Handoff sessione** — stato corrente per nuova chat AI
- **[WISHLIST.md](./WISHLIST.md)** — Funzionalità future (riferimenti XEP)

---

## Decisioni (ADR)

- [decisions/address-based-messaging.md](./decisions/address-based-messaging.md) — **🟢 Vincolante** — messaggistica per indirizzo; inbox on-read
- [decisions/no-internal-external-chat-distinction.md](./decisions/no-internal-external-chat-distinction.md) — **🟢 Vincolante** — chat unificate
- [decisions/server-as-reception.md](./decisions/server-as-reception.md) — **🟢 Vincolante** — concept spunte cloud
- [decisions/bridge-stateless.md](./decisions/bridge-stateless.md) — **🟢 Vincolante** — bridge senza stato di business
- [decisions/multi-account-parallel-sessions.md](./decisions/multi-account-parallel-sessions.md) — **🟢 Vincolante** — multi-account (UX #140, una GoTrue #152)
- [decisions/single-device-logout-open.md](./decisions/single-device-logout-open.md) — **🟢** Logout locale; futuro «Disconnetti ovunque»
- [decisions/README.md](./decisions/README.md) — Indice ADR

---

## Architettura

- [architecture/alpha-full-stack.md](./architecture/alpha-full-stack.md) — **🟢 Alpha** — client + Supabase
- [architecture/alpha-pr-registry.md](./architecture/alpha-pr-registry.md) — Registro PR **#108–#163**
- [architecture/mailbox-inbox-outbox-spec.md](./architecture/mailbox-inbox-outbox-spec.md) — **🟢 Implementato** — modello caselle (PR #159)
- [architecture/README.md](./architecture/README.md) — Indice architettura

---

## Implementazione

- [implementation/voice-notes.md](./implementation/voice-notes.md) — Note vocali WebM/Opus (PR #126)
- [implementation/location-sharing.md](./implementation/location-sharing.md) — Posizione statica in chat (PR #153)
- [implementation/groups-client.md](./implementation/groups-client.md) — Account gruppo, shell, UI autore (PR #162)
- [implementation/peer-profile-overlay.md](./implementation/peer-profile-overlay.md) — Scheda profilo peer, tap avatar (PR #163)
- [implementation/README.md](./implementation/README.md) — Indice implementazione

---

## Fix

- [fixes/flutter-inbox-stability.md](./fixes/flutter-inbox-stability.md) — Race auth + provider (#113/#114); evoluzione multi-account
- [fixes/auth-bootstrap-gotrue-revoke.md](./fixes/auth-bootstrap-gotrue-revoke.md) — Bootstrap signOut / PKCE (#142)
- [fixes/multi-account-chat-persistence-pr143.md](./fixes/multi-account-chat-persistence-pr143.md) — PR #143 — logout locale, view per account
- [fixes/multi-account-single-active-gotrue-pr152.md](./fixes/multi-account-single-active-gotrue-pr152.md) — PR #152 — una GoTrue attiva
- [fixes/README.md](./fixes/README.md) — Indice fix

---

## Design

- [design/conversation-bottom-anchor.md](./design/conversation-bottom-anchor.md) — Aggancio al fondo chat (PR #125)
- [design/inbox-search-toggle.md](./design/inbox-search-toggle.md) — Ricerca inbox on-demand (PR #132)
- [design/auth-overlay-shell.md](./design/auth-overlay-shell.md) — Overlay credenziali su shell (PR #140)
- [design/README.md](./design/README.md) — Indice design

---

**Ultimo aggiornamento**: 2026-07-06 — GROUP-CORE/DELIVERY (#162); pulizia contenuto obsoleto; solo spec e doc operativi
