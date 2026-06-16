# Alfred - XMPP Client Web

## Scopo di questo documento

Questo documento traccia lo stato del progetto Alfred per continuità del lavoro e comprensione architetturale. NON è documentazione per utenti esterni.

## Overview Tecnica

Alfred è un client XMPP web-based costruito con React 19 + TypeScript + Vite. Implementa protocollo XMPP tramite Stanza.js con architettura offline-first basata su IndexedDB.

### Metriche Performance Chiave

- Apertura chat: < 100ms (cache hit)
- Lista conversazioni: < 200ms (cache hit)
- Sync iniziale (DB vuoto): ~5-10s per 100 conversazioni
- Sync incrementale (DB popolato): ~2-5s per aggiornamenti
- Avvii successivi: < 5s (solo delta dal marker)
- Build production: ~15s (code splitting attivo)

## Feature Implementate (Riferimento Rapido)

Vedi `PROJECT_MAP.md` per dettagli completi.

**Core Funzionante**:
- Login XMPP con auto-login
- Lista conversazioni con sync ottimizzata
- Chat 1-to-1 con real-time messaging
- Spunte WhatsApp 3 livelli: ✓ inviato, ✓✓ grigie (XEP-0184), ✓✓ blu (XEP-0333)
- vCard (avatar, profilo)
- Sync iniziale intelligente (full/incremental)
- MAM (XEP-0313) con marcatori RSM
- Push Notifications (XEP-0357) - richiede server con supporto
- Cache-first con IndexedDB
- Real-time message updates (no polling)

**In Roadmap** (non iniziato):
- MUC (XEP-0045)
- OMEMO (XEP-0384)
- File upload (XEP-0363)
- Voice/Video calls
- Dark mode
- Emoji picker

## Build e Development

```bash
cd web-client
npm install
npm run dev       # Dev server su http://localhost:5173/XmppTest/
npm run build     # Build production in dist/
npm run preview   # Preview build locale
```

**Note Tecniche**:
- Base URL `/XmppTest/` per GitHub Pages
- HashRouter per compatibility hosting statico
- Hot reload funzionante con Vite

## Accesso Produzione

**URL Live**: https://alfred-im.github.io/XmppTest/

**Credenziali Test**:
- **Username**: `testardo@conversations.im`
- **Password**: `FyqnD2YpGScNsuC`

Vedi `TEST_CREDENTIALS.md` per altri account di test disponibili.

**Note**:
- Prima apertura: sync iniziale ~5-10 secondi
- Aperture successive: ~2 secondi (sync incrementale)
- Server XMPP: conversations.im

## Architettura (Sintesi)

Vedi `PROJECT_MAP.md` per architettura dettagliata completa.

**Layer**:
- UI Layer: Pages, Components
- Initialization Layer: AppInitializer (gestisce sync all'avvio)
- Context Layer: ConnectionContext, ConversationsContext, MessagingContext, AuthContext
- Services Layer: sync-initializer.ts, messages.ts, conversations.ts, vcard.ts
- Repository Layer: ConversationRepository, MessageRepository, VCardRepository, MetadataRepository
- Data Layer: IndexedDB (alfred-xmpp-db) + XMPP Server

**Principi**:
1. **Sync-Once + Listen**: Sincronizzazione solo all'avvio, poi solo messaggi real-time
2. **Cache-First**: Mostra sempre prima dati locali
3. **Incremental Sync**: DB vuoto → full sync, DB popolato → solo nuovi messaggi
4. **Offline-First**: Funziona senza connessione
5. **Separation of Concerns**: Layer ben definiti

## Documentazione (Struttura)

**Documenti Chiave per AI**:
- `PROJECT_MAP.md` - **LEGGERE ALL'INIZIO DI OGNI SESSIONE** (regola fondamentale)
- `.cursor-rules.md` - Regole di sviluppo
- `docs/architecture/` - Analisi architetturali (MAM strategy, conversazioni, performance)
- `docs/implementation/` - Dettagli implementazioni (login, sync, scrollable containers, chat markers)
- `docs/decisions/` - ADR (decisioni architetturali)
- `docs/fixes/` - Analisi fix applicati
- `docs/design/` - Principi design (brand identity, database architecture)
- `docs/archive/` - Documentazione storica

**Indice Navigabile**: `docs/INDICE.md`

## Known Issues e Limitazioni

Vedi `docs/fixes/known-issues.md` per lista completa aggiornata.

**Critici**:
- Push Notifications richiedono server XMPP con XEP-0357 (jabber.hot-chilli.net e conversations.im NON supportano)
- Password in plain text in localStorage (encryption pianificata)

**Performance**:
- MAM sync iniziale lenta con >5000 messaggi
- Alcuni server XMPP non supportano vCard photo

## Test Credentials

Vedi `TEST_CREDENTIALS.md` per account di test configurati.

**Quick reference**:
- `testardo@conversations.im` / `FyqnD2YpGScNsuC`
- `testarda@conversations.im` / `FyqnD2YpGScNsuC`

## License

MIT License - Vedi file `LICENSE`

---

**Ultimo aggiornamento**: 2025-12-17  
**Versione corrente**: 1.0.1  
**Architettura**: Sync-Once + Listen (implementata 15 dicembre 2025)  
**Auto-login**: Ripristinato e funzionante con localStorage (17 dicembre 2025)
