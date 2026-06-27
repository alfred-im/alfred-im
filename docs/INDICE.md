# Indice Documentazione (Riferimento AI)

Indice documenti tecnici per navigazione rapida. Questo documento è per AI, non per utenti.

## ⚠️ Client attivo: Flutter (`client/`)

- **Live**: https://alfred-im.github.io/XmppTest/
- **Legacy React**: rimosso da `main` — percorsi `web-client/` nei doc sotto = tag `legacy/web-client-final` (`6e792eb`)

Recupero codice legacy: `git checkout legacy/web-client-final -- web-client/`

## Documenti Root

- **[.cursor/rules/main.mdc](../.cursor/rules/main.mdc)** - Vincolo Cursor: obbligo lettura `.cursor-rules.md` + puntatori documentazione
- **[PROJECT_MAP.md](../PROJECT_MAP.md)** - **LEGGERE ALL'INIZIO DI OGNI SESSIONE** (regola fondamentale)
- **[README.md](../README.md)** - Stato progetto e riferimenti
- **[CHANGELOG.md](../CHANGELOG.md)** - Storia modifiche tecniche
- **[.cursor-rules.md](../.cursor-rules.md)** - Regole sviluppo AI (fonte autoritativa, non modificare)
- **[TEST_CREDENTIALS.md](../TEST_CREDENTIALS.md)** - Credenziali test
- **[WISHLIST.md](./WISHLIST.md)** - Funzionalità future desiderate con riferimenti XEP

---

## Decisioni (ADR)

- [decisions/no-internal-external-chat-distinction.md](./decisions/no-internal-external-chat-distinction.md) - **🟢 Regola vincolante** — nessuna distinzione chat interna/esterna (client, piattaforma, bridge, test) (2026-06-27)
- [decisions/server-as-reception.md](./decisions/server-as-reception.md) - **🟢 Concept spunte cloud** — ricezione = ricezione sul server (2026-06-26)

## Architettura

- [architecture/mailbox-inbox-outbox-spec.md](./architecture/mailbox-inbox-outbox-spec.md) - **📋 Proposta** — modello caselle, outbox unificata, flusso email (2026-06-26)
- [architecture/alpha-full-stack.md](./architecture/alpha-full-stack.md) - **🟢 Alpha completa** — client + Supabase, senza bridge (§2.10 aggancio al fondo, 2026-06-27)
- [architecture/alpha-pr-registry.md](./architecture/alpha-pr-registry.md) - **Registro PR Alpha #108–#114** — cosa documentare dopo ogni merge
- [architecture/conversations-analysis.md](./architecture/conversations-analysis.md) - Analisi conversazioni XMPP
- [architecture/mam-global-strategy-explained.md](./architecture/mam-global-strategy-explained.md) - Strategia MAM globale
- [architecture/mam-performance-long-term.md](./architecture/mam-performance-long-term.md) - Performance MAM
- [architecture/strategy-comparison.md](./architecture/strategy-comparison.md) - Confronto strategie
- [architecture/message-states.md](./architecture/message-states.md) - **Stati messaggio + spunte WhatsApp 3 livelli** (v2.1 - 16 giu 2026)

## Implementazione

- [implementation/README.md](./implementation/README.md) - Overview implementazioni
- [implementation/login-system.md](./implementation/login-system.md) - Sistema login popup (⚠️ storico — vedi nota in file)
- [implementation/sync-system-complete.md](./implementation/sync-system-complete.md) - **Virtual UI + MAM-only DB + isolamento account** (v4.0 / v2.2)
- [implementation/scrollable-containers.md](./implementation/scrollable-containers.md) - Utility class scroll
- [implementation/scrollable-containers-implementation.md](./implementation/scrollable-containers-implementation.md) - Dettagli tecnici
- [implementation/delivery-receipts-xep-0184.md](./implementation/delivery-receipts-xep-0184.md) - **XEP-0184** livello 2 (✓✓ grigie consegnato)
- [implementation/chat-markers-xep-0333.md](./implementation/chat-markers-xep-0333.md) - **XEP-0333** livello 3 (✓✓ blu lettura)

## Fixes

- [fixes/README.md](./fixes/README.md) - Overview fix
- [fixes/flutter-inbox-stability.md](./fixes/flutter-inbox-stability.md) - **Fix inbox Flutter** — race auth + ChangeNotifierProxyProvider (PR #113/#114)
- [fixes/account-storage-isolation.md](./fixes/account-storage-isolation.md) - **Isolamento IndexedDB per account** (17 giu 2026, legacy React)
- [fixes/auto-login-fix-2025-12-17.md](./fixes/auto-login-fix-2025-12-17.md) - Fix auto-login ConnectionContext
- [fixes/profile-save-error-fix.md](./fixes/profile-save-error-fix.md) - Fix errori salvataggio profilo
- [fixes/profile-scroll-conflict-fix.md](./fixes/profile-scroll-conflict-fix.md) - Fix conflitti scroll
- [fixes/profile-scroll-fix.md](./fixes/profile-scroll-fix.md) - Fix scroll profilo
- [fixes/vcard-photo-base64-string-fix.md](./fixes/vcard-photo-base64-string-fix.md) - Fix formato foto
- [fixes/vcard-photo-server-issue.md](./fixes/vcard-photo-server-issue.md) - Analisi problemi vCard
- [fixes/known-issues.md](./fixes/known-issues.md) - Known issues

## Design

- [design/README.md](./design/README.md) - Principi design (Note: brand identity e database architecture integrati in PROJECT_MAP.md)
- [design/conversation-bottom-anchor.md](./design/conversation-bottom-anchor.md) - **🟢 Aggancio al fondo** — scroll ancorato, stacco, riaggancio, UI correlata (2026-06-27)

## Decisioni Architetturali (ADR)

- [decisions/bridge-stateless.md](./decisions/bridge-stateless.md) - **Bridge stateless — stato solo in piattaforma** (vincolante)
- [decisions/project-revolution-discovery.md](./decisions/project-revolution-discovery.md) - **🟡 Discovery Q&A rivoluzione progetto** (iterazioni in corso)
- [decisions/README.md](./decisions/README.md) - Overview decisioni
- [decisions/no-message-deletion.md](./decisions/no-message-deletion.md) - Decisione no message deletion
- [decisions/no-modify-source-data.md](./decisions/no-modify-source-data.md) - Regola: non modificare la fonte dati

## Archivio

### Ricerca XMPP
- [archive/xmpp-research/xmpp-message-deletion-research.md](./archive/xmpp-research/xmpp-message-deletion-research.md)
- [archive/xmpp-research/xmpp-deletion-comprehensive-analysis.md](./archive/xmpp-research/xmpp-deletion-comprehensive-analysis.md)
- [archive/xmpp-research/xep-0424-support-analysis.md](./archive/xmpp-research/xep-0424-support-analysis.md)
- [archive/xmpp-research/xmpp-hide-message-history.md](./archive/xmpp-research/xmpp-hide-message-history.md)
- [archive/xmpp-research/xmpp-hide-conversation-flag.md](./archive/xmpp-research/xmpp-hide-conversation-flag.md)

### Documentazione Storica
- [archive/README.md](./archive/README.md)
- [archive/old-docs/](./archive/old-docs/)

---

**Ultimo aggiornamento**: 2026-06-27 (aggancio al fondo + ADR chat unificate)  
**Client live**: Flutter + Supabase @ https://alfred-im.github.io/XmppTest/  
**Legacy (riferimento doc)**: React @ `legacy/web-client-final`
