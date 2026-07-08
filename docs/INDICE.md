# Indice Documentazione (Riferimento AI)

Indice documenti tecnici per navigazione rapida. Documento per AI, non per utenti.

## Client attivo

- **Live**: https://alfred-im.github.io/XmppTest/
- **Codice**: `client/` (Flutter + Supabase)

---

## Spec (SDD) — registro promesse

**Metodo**: [specs/README.md](./specs/README.md) · **Registro**: [specs/registry.md](./specs/registry.md) · **Indice**: [specs/index.md](./specs/index.md)

### SYSTEM

| ID | Stato | Contenuto |
|----|-------|-----------|
| [SYS-MAILBOX](./specs/promises/system/SYS-MAILBOX.md) | `implemented` | Archivio per owner, invio, inbox, spunte |
| [SYS-GROUP](./specs/promises/system/SYS-GROUP.md) | `implemented` | Account gruppo, erogazione |
| [SYS-PROFILE](./specs/promises/system/SYS-PROFILE.md) | `implemented` | Tabella `profiles`, avatar, RPC |
| [SYS-CONTACTS](./specs/promises/system/SYS-CONTACTS.md) | `implemented` | Rubrica, `search_profiles` |
| [SYS-RECEPTION](./specs/promises/system/SYS-RECEPTION.md) | `implemented` | Allow list ricezione, gate server |
| [contracts/rpc.md](./specs/contracts/rpc.md) | `implemented` | Firme RPC (dettaglio DDL) |
| [contracts/schema.md](./specs/contracts/schema.md) | `implemented` | Schema DB, RLS, storage |

### PRODUCT

| ID | Stato | Contenuto |
|----|-------|-----------|
| [PROM-LIST-FILTER](./specs/promises/product/PROM-LIST-FILTER.md) | `implemented` | Filtro locale + ricerca on-demand |
| [PROM-MULTI-ACCOUNT](./specs/promises/product/PROM-MULTI-ACCOUNT.md) | `implemented` | Manifest, focus, una GoTrue |
| [PROM-PROFILE-IDENTITY](./specs/promises/product/PROM-PROFILE-IDENTITY.md) | `implemented` | `ProfileSummary`, widget identità |
| [PROM-PERSONAL-CONTACTS](./specs/promises/product/PROM-PERSONAL-CONTACTS.md) | `implemented` | Rubrica isolata da inbox |
| [PROM-RECEPTION-FILTER](./specs/promises/product/PROM-RECEPTION-FILTER.md) | `implemented` | Filtro ricezione, rifiuto silenzioso |
| [PROM-PEER-PROFILE](./specs/promises/product/PROM-PEER-PROFILE.md) | `implemented` | Overlay profilo peer |
| [PROM-CHAT-PEER-KEY](./specs/promises/product/PROM-CHAT-PEER-KEY.md) | `implemented` | Chat per `peer_profile_id` |
| [PROM-OUTBOUND-SEND](./specs/promises/product/PROM-OUTBOUND-SEND.md) | `implemented` | Coda invio optimistic |
| [PROM-MESSAGE-STATUS](./specs/promises/product/PROM-MESSAGE-STATUS.md) | `implemented` | Spunte da date mailbox |
| [PROM-REALTIME-OWNER](./specs/promises/product/PROM-REALTIME-OWNER.md) | `implemented` | Realtime su `owner_id` |
| [PROM-GROUP-AUTHOR-DISPLAY](./specs/promises/product/PROM-GROUP-AUTHOR-DISPLAY.md) | `implemented` | Autore in chat gruppo |
| [PROM-GROUP-TICKS](./specs/promises/product/PROM-GROUP-TICKS.md) | `implemented` | Spunte gruppo |
| [PROM-OVERLAY-DISMISS](./specs/promises/product/PROM-OVERLAY-DISMISS.md) | `implemented` | Chiusura overlay |

### SURFACE

| ID | Stato | Contenuto |
|----|-------|-----------|
| [SURF-AUTH](./specs/surfaces/SURF-AUTH.md) | `implemented` | Overlay login/registrazione |
| [SURF-ACCOUNT-SIDEBAR](./specs/surfaces/SURF-ACCOUNT-SIDEBAR.md) | `implemented` | Manifest in sidebar |
| [SURF-INBOX](./specs/surfaces/SURF-INBOX.md) | `implemented` | Lista conversazioni |
| [SURF-CHAT](./specs/surfaces/SURF-CHAT.md) | `implemented` | Chat 1:1 |
| [SURF-CONTACTS](./specs/surfaces/SURF-CONTACTS.md) | `implemented` | Rubrica |
| [SURF-ALLOWLIST](./specs/surfaces/SURF-ALLOWLIST.md) | `implemented` | Persone consentite |
| [SURF-PROFILE](./specs/surfaces/SURF-PROFILE.md) | `implemented` | Modifica profilo |
| [SURF-PEER-PROFILE](./specs/surfaces/SURF-PEER-PROFILE.md) | `implemented` | Scheda profilo peer |
| [SURF-GROUP-SHELL](./specs/surfaces/SURF-GROUP-SHELL.md) | `implemented` | Shell account gruppo |
| [SURF-GROUP-CONVERSATION](./specs/surfaces/SURF-GROUP-CONVERSATION.md) | `implemented` | Chat gruppo |

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
- [architecture/alpha-pr-registry.md](./architecture/alpha-pr-registry.md) — Registro PR **#108–#172**
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

> Evidenza UX — contratti in [registry.md](./specs/registry.md).

- [design/conversation-bottom-anchor.md](./design/conversation-bottom-anchor.md) — Aggancio al fondo chat (PR #125); backlog PROM
- [design/inbox-search-toggle.md](./design/inbox-search-toggle.md) — → PROM-LIST-FILTER (PR #132, #171)
- [design/auth-overlay-shell.md](./design/auth-overlay-shell.md) — → SURF-AUTH (PR #140)
- [design/README.md](./design/README.md) — Indice design

---

**Ultimo aggiornamento**: 2026-07-08 — SDD registro promesse; 5 SYS + 13 PROM + 10 SURF
