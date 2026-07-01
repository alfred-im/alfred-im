# Indice Documentazione (Riferimento AI)

Indice documenti tecnici per navigazione rapida. Documento per AI, non per utenti.

## Client attivo

- **Live**: https://alfred-im.github.io/XmppTest/
- **Codice**: `client/` (Flutter + Supabase)

---

## Documenti root

- **[.cursor/rules/main.mdc](../.cursor/rules/main.mdc)** — Vincolo Cursor → `.cursor-rules.md`
- **[PROJECT_MAP.md](../PROJECT_MAP.md)** — **Leggere all'inizio di ogni sessione**
- **[README.md](../README.md)** — Stato progetto
- **[CHANGELOG.md](../CHANGELOG.md)** — Storia modifiche
- **[.cursor-rules.md](../.cursor-rules.md)** — Regole sviluppo AI
- **[TEST_CREDENTIALS.md](../TEST_CREDENTIALS.md)** — Credenziali test XMPP (legacy)
- **[AGENT_DEBUG_ACCOUNTS.md](./AGENT_DEBUG_ACCOUNTS.md)** — **Account Supabase solo agente** + regola non toccare test1/2/3
- **[SESSION_HANDOFF.md](./SESSION_HANDOFF.md)** — **Handoff sessione** — stato corrente per nuova chat AI
- **[WISHLIST.md](./WISHLIST.md)** — Funzionalità future (riferimenti XEP)

---

## Decisioni (ADR)

- [decisions/address-based-messaging.md](./decisions/address-based-messaging.md) — **🟢 Vincolante** — messaggistica per indirizzo; inbox on-read
- [decisions/no-internal-external-chat-distinction.md](./decisions/no-internal-external-chat-distinction.md) — **🟢 Vincolante** — chat unificate
- [decisions/server-as-reception.md](./decisions/server-as-reception.md) — Concept spunte cloud
- [decisions/bridge-stateless.md](./decisions/bridge-stateless.md) — Bridge senza stato di business
- [decisions/multi-account-parallel-sessions.md](./decisions/multi-account-parallel-sessions.md) — **🟢 Vincolante** — sessioni Supabase parallele per account aperti
- [decisions/single-device-logout-open.md](./decisions/single-device-logout-open.md) — **🟡 Aperto** — logout per dispositivo vs revoca globale
- [decisions/project-revolution-discovery.md](./decisions/project-revolution-discovery.md) — Visione e discovery Alpha
- [decisions/no-message-deletion.md](./decisions/no-message-deletion.md) — No cancellazione messaggi
- [decisions/no-modify-source-data.md](./decisions/no-modify-source-data.md) — Non modificare la fonte dati
- [decisions/README.md](./decisions/README.md) — Indice ADR

---

## Architettura

- [architecture/alpha-full-stack.md](./architecture/alpha-full-stack.md) — **🟢 Alpha** — client + Supabase
- [architecture/alpha-pr-registry.md](./architecture/alpha-pr-registry.md) — Registro PR #108–#140
- [architecture/mailbox-inbox-outbox-spec.md](./architecture/mailbox-inbox-outbox-spec.md) — **🟡 Target** — modello caselle (direzione confermata; non su `main`)
- [architecture/README.md](./architecture/README.md) — Indice architettura

---

## Implementazione

- [implementation/messages-only-inbox.md](./implementation/messages-only-inbox.md) — Inbox solo messaggi (PR #130)
- [implementation/voice-notes.md](./implementation/voice-notes.md) — Note vocali WebM/Opus (PR #126)
- [implementation/multi-account-client.md](./implementation/multi-account-client.md) — **🟢** Sessioni Supabase parallele (PR #140)
- [implementation/multi-account-persistence-redesign.md](./implementation/multi-account-persistence-redesign.md) — **🟡 Prossima implementazione** — redesign persistenza, single source of truth (2026-07-01)
- [implementation/README.md](./implementation/README.md) — Indice implementazione

---

## Fix

- [fixes/flutter-inbox-stability.md](./fixes/flutter-inbox-stability.md) — Race auth + provider inbox (#113/#114); evoluzione post #140
- [fixes/auth-bootstrap-gotrue-revoke.md](./fixes/auth-bootstrap-gotrue-revoke.md) — Bootstrap signOut revoca refresh; PKCE (#141/#142)
- [fixes/multi-account-chat-persistence-pr143.md](./fixes/multi-account-chat-persistence-pr143.md) — **PR #143** — logout locale, chat multi-account, persistenza F5
- [fixes/README.md](./fixes/README.md) — Indice fix

---

## Design

- [design/conversation-bottom-anchor.md](./design/conversation-bottom-anchor.md) — Aggancio al fondo chat (PR #125)
- [design/inbox-search-toggle.md](./design/inbox-search-toggle.md) — Ricerca inbox on-demand (PR #132)
- [design/auth-overlay-shell.md](./design/auth-overlay-shell.md) — Overlay credenziali su shell (PR #140)
- [design/README.md](./design/README.md) — Indice design

---

**Ultimo aggiornamento**: 2026-07-01 — redesign persistenza multi-account (doc implementazione)
