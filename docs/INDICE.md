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
- **[TEST_CREDENTIALS.md](../TEST_CREDENTIALS.md)** — Credenziali test
- **[WISHLIST.md](./WISHLIST.md)** — Funzionalità future (riferimenti XEP)

---

## Decisioni (ADR)

- [decisions/address-based-messaging.md](./decisions/address-based-messaging.md) — **🟢 Vincolante** — messaggistica per indirizzo; inbox on-read
- [decisions/no-internal-external-chat-distinction.md](./decisions/no-internal-external-chat-distinction.md) — **🟢 Vincolante** — chat unificate
- [decisions/server-as-reception.md](./decisions/server-as-reception.md) — Concept spunte cloud
- [decisions/bridge-stateless.md](./decisions/bridge-stateless.md) — Bridge senza stato di business
- [decisions/project-revolution-discovery.md](./decisions/project-revolution-discovery.md) — Visione e discovery Alpha
- [decisions/no-message-deletion.md](./decisions/no-message-deletion.md) — No cancellazione messaggi
- [decisions/no-modify-source-data.md](./decisions/no-modify-source-data.md) — Non modificare la fonte dati
- [decisions/README.md](./decisions/README.md) — Indice ADR

---

## Architettura

- [architecture/alpha-full-stack.md](./architecture/alpha-full-stack.md) — **🟢 Alpha** — client + Supabase
- [architecture/alpha-pr-registry.md](./architecture/alpha-pr-registry.md) — Registro PR #108–#132
- [architecture/mailbox-inbox-outbox-spec.md](./architecture/mailbox-inbox-outbox-spec.md) — **📋 Idea** — delta modello caselle (non adottata; dettagli da dedurre da Alpha)
- [architecture/README.md](./architecture/README.md) — Indice architettura

---

## Implementazione

- [implementation/messages-only-inbox.md](./implementation/messages-only-inbox.md) — Inbox solo messaggi (PR #130)
- [implementation/voice-notes.md](./implementation/voice-notes.md) — Note vocali WebM/Opus (PR #126)
- [implementation/README.md](./implementation/README.md) — Indice implementazione

---

## Fix

- [fixes/flutter-inbox-stability.md](./fixes/flutter-inbox-stability.md) — Race auth + provider inbox (PR #113/#114)
- [fixes/README.md](./fixes/README.md) — Indice fix

---

## Design

- [design/conversation-bottom-anchor.md](./design/conversation-bottom-anchor.md) — Aggancio al fondo chat (PR #125)
- [design/inbox-search-toggle.md](./design/inbox-search-toggle.md) — Ricerca inbox on-demand (PR #132)
- [design/README.md](./design/README.md) — Indice design

---

**Ultimo aggiornamento**: 2026-06-28 — rimozione documentazione client React/XMPP; solo stack Flutter attivo
