# Indice Documentazione (Riferimento AI)

Indice documenti tecnici per navigazione rapida. Questo documento è per AI, non per utenti.

## Documenti Root

- **[PROJECT_MAP.md](../PROJECT_MAP.md)** - **LEGGERE ALL'INIZIO DI OGNI SESSIONE** (regola fondamentale)
- **[README.md](../README.md)** - Stato progetto e riferimenti
- **[CHANGELOG.md](../CHANGELOG.md)** - Storia modifiche tecniche
- **[.cursor-rules.md](../.cursor-rules.md)** - Regole sviluppo AI
- **[TEST_CREDENTIALS.md](../TEST_CREDENTIALS.md)** - Credenziali test
- **[WISHLIST.md](./WISHLIST.md)** - Funzionalità future desiderate con riferimenti XEP

---

## Architettura

- [architecture/README.md](./architecture/README.md) - Overview architetturale
- [architecture/conversations-analysis.md](./architecture/conversations-analysis.md) - Analisi conversazioni XMPP
- [architecture/mam-global-strategy-explained.md](./architecture/mam-global-strategy-explained.md) - Strategia MAM globale
- [architecture/mam-performance-long-term.md](./architecture/mam-performance-long-term.md) - Performance MAM
- [architecture/strategy-comparison.md](./architecture/strategy-comparison.md) - Confronto strategie
- [architecture/message-states.md](./architecture/message-states.md) - **Stati messaggio + spunte WhatsApp 3 livelli** (v2.0 - 16 giu 2026)

## Implementazione

- [implementation/README.md](./implementation/README.md) - Overview implementazioni
- [implementation/login-system.md](./implementation/login-system.md) - Sistema login popup
- [implementation/sync-system-complete.md](./implementation/sync-system-complete.md) - **Sistema "Sync-Once + Listen"** (v3.0 - 15 dic 2025)
- [implementation/scrollable-containers.md](./implementation/scrollable-containers.md) - Utility class scroll
- [implementation/scrollable-containers-implementation.md](./implementation/scrollable-containers-implementation.md) - Dettagli tecnici
- [implementation/delivery-receipts-xep-0184.md](./implementation/delivery-receipts-xep-0184.md) - **XEP-0184** livello 2 (✓✓ grigie consegnato)
- [implementation/chat-markers-xep-0333.md](./implementation/chat-markers-xep-0333.md) - **XEP-0333** livello 3 (✓✓ blu lettura)

## Fixes

- [fixes/README.md](./fixes/README.md) - Overview fix
- [fixes/profile-save-error-fix.md](./fixes/profile-save-error-fix.md) - Fix errori salvataggio profilo
- [fixes/profile-scroll-conflict-fix.md](./fixes/profile-scroll-conflict-fix.md) - Fix conflitti scroll
- [fixes/profile-scroll-fix.md](./fixes/profile-scroll-fix.md) - Fix scroll profilo
- [fixes/vcard-photo-base64-string-fix.md](./fixes/vcard-photo-base64-string-fix.md) - Fix formato foto
- [fixes/vcard-photo-server-issue.md](./fixes/vcard-photo-server-issue.md) - Analisi problemi vCard
- [fixes/known-issues.md](./fixes/known-issues.md) - Known issues

## Design

- [design/README.md](./design/README.md) - Principi design (Note: brand identity e database architecture integrati in PROJECT_MAP.md)

## Decisioni Architetturali (ADR)

- [decisions/README.md](./decisions/README.md) - Overview decisioni
- [decisions/no-message-deletion.md](./decisions/no-message-deletion.md) - Decisione no message deletion

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

**Ultimo aggiornamento**: 2026-06-16  
**Architettura corrente**: Virtual UI + MAM-only DB (v4.0) + Spunte WhatsApp (XEP-0184 + XEP-0333)
