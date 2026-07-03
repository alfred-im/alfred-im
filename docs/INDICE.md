# Indice Documentazione (Riferimento AI)

Indice documenti tecnici per navigazione rapida. Documento per AI, non per utenti.

## Client attivo

- **Live**: https://alfred-im.github.io/XmppTest/
- **Codice**: `client/` (Flutter + Supabase)

---

## Spec (SDD) — contratti capability

**Metodo**: [specs/README.md](./specs/README.md) · **Catalogo**: [specs/index.md](./specs/index.md)

| Spec | Stato | Contenuto |
|------|-------|-----------|
| [MSG-INBOX](./specs/capabilities/MSG-INBOX.spec.md) | `implemented` | Inbox on-read, `ChatPeer`, realtime |
| [MSG-SEND](./specs/capabilities/MSG-SEND.spec.md) | `implemented` | Invio testo/GIF/voice/location, coda retry |
| [MSG-READ](./specs/capabilities/MSG-READ.spec.md) | `implemented` | Spunte delivered/read, `mark_peer_read` |
| [INBOX-SEARCH](./specs/capabilities/INBOX-SEARCH.spec.md) | `implemented` | Ricerca conversazioni on-demand |
| [PROFILE](./specs/capabilities/PROFILE.spec.md) | `implemented` | Profilo, avatar, pronomi, `ProfileSummary` |
| [AUTH-MULTI](./specs/capabilities/AUTH-MULTI.spec.md) | `implemented` | Multi-account, focus, overlay shell |
| [contracts/rpc.md](./specs/contracts/rpc.md) | `implemented` | Firme RPC messaggistica |

Target futuro caselle: [architecture/mailbox-inbox-outbox-spec.md](./architecture/mailbox-inbox-outbox-spec.md) (non ancora spec capability).

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

> Storico client React/XMPP: tag `legacy/web-client-final` — non su `main`.

---

## Decisioni (ADR)

- [decisions/address-based-messaging.md](./decisions/address-based-messaging.md) — **🟢 Vincolante** — messaggistica per indirizzo; inbox on-read
- [decisions/no-internal-external-chat-distinction.md](./decisions/no-internal-external-chat-distinction.md) — **🟢 Vincolante** — chat unificate
- [decisions/server-as-reception.md](./decisions/server-as-reception.md) — Concept spunte cloud
- [decisions/bridge-stateless.md](./decisions/bridge-stateless.md) — Bridge senza stato di business
- [decisions/multi-account-parallel-sessions.md](./decisions/multi-account-parallel-sessions.md) — **🟢 Vincolante** — multi-account (UX #140, una GoTrue #152)
- [decisions/single-device-logout-open.md](./decisions/single-device-logout-open.md) — **🟢** Logout locale; futuro «Disconnetti ovunque»
- [decisions/project-revolution-discovery.md](./decisions/project-revolution-discovery.md) — Visione stack (discovery completata, storico)
- [decisions/README.md](./decisions/README.md) — Indice ADR

---

## Architettura

- [architecture/alpha-full-stack.md](./architecture/alpha-full-stack.md) — **🟢 Alpha** — client + Supabase
- [architecture/alpha-pr-registry.md](./architecture/alpha-pr-registry.md) — Registro PR **#108–#153**
- [architecture/mailbox-inbox-outbox-spec.md](./architecture/mailbox-inbox-outbox-spec.md) — **🟡 Target** — modello caselle (non su `main`)
- [architecture/README.md](./architecture/README.md) — Indice architettura

---

## Implementazione

- [implementation/messages-only-inbox.md](./implementation/messages-only-inbox.md) — Inbox solo messaggi (PR #130)
- [implementation/voice-notes.md](./implementation/voice-notes.md) — Note vocali WebM/Opus (PR #126)
- [implementation/location-sharing.md](./implementation/location-sharing.md) — Posizione statica in chat (PR #153)
- [implementation/multi-account-client.md](./implementation/multi-account-client.md) — **🟢** Multi-account (#140, #147, #152)
- [implementation/multi-account-persistence-redesign.md](./implementation/multi-account-persistence-redesign.md) — **✅ Storico design** (#147 implementato)
- [implementation/README.md](./implementation/README.md) — Indice implementazione

---

## Fix

- [fixes/flutter-inbox-stability.md](./fixes/flutter-inbox-stability.md) — Race auth + provider (#113/#114); evoluzione multi-account
- [fixes/auth-bootstrap-gotrue-revoke.md](./fixes/auth-bootstrap-gotrue-revoke.md) — Bootstrap signOut / PKCE (#142)
- [fixes/conversations-empty-diagnosis.md](./fixes/conversations-empty-diagnosis.md) — Chat vuota vs sessione morta (risolto #143/#147/#152)
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

**Ultimo aggiornamento**: 2026-07-03 — PROFILE spec + SDD catalogo
