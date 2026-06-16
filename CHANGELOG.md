# Changelog Tecnico

Modifiche rilevanti al progetto per tracciare evoluzione tecnica e decisioni implementative. Questo documento è per riferimento interno AI, non per utenti esterni.

---

## [Unreleased]

### Aggiunto
- **Spunte WhatsApp 3 livelli**: ✓ inviato, ✓✓ grigie (XEP-0184), ✓✓ blu (XEP-0333)
- **Virtual UI + MAM-only DB**: listener campanello, outbox, origin-id canonico
- **XEP-0184**: `receipt request` in invio, listener `receipt`, overlay `deliveredUi`
- **Documentazione**: `message-states.md` v2.0, `delivery-receipts-xep-0184.md`
- **Sync Boundary Handoff**: all'avvio salva momento T, attiva listener da T, sync MAM fino a T + 5s overlap

### Rimosso
- **Codice morto**: `sync.ts`, `SyncService.ts`, `usePullToRefresh.ts`, `src/repositories/`, `App.css`
- **Funzioni non usate**: `loadAllConversations`, `updateConversationOnNewMessage`, `reloadAllMessagesFromServer`, `handleIncomingMessage`
- **Documentazione obsoleta**: `pull-to-refresh-fix.md`, `INTEGRAZIONE_MAPPA_COMPLETATA.md`, riferimenti a sync legacy e pull-to-refresh custom

### Corretti / Completati
- **Re-sync su reconnect**: `AppInitializer` resetta lo stato sync alla disconnessione
- **LoginPopup**: gestisce correttamente errori di `connect()`
- **Lista conversazioni**: aggiornamento mirato con `refreshConversation()` invece di reload completo
- **Persistence messaggi**: salvataggio unificato via `messageRepository` (rimosso wrapper circolare in `conversations-db`)
- **CSS morto**: rimossi stili pull-to-refresh non usati

### Da Fare
- Chat di gruppo (MUC - XEP-0045)
- Crittografia E2E (OMEMO - XEP-0384)
- Condivisione file (HTTP Upload - XEP-0363)
- Voice/Video calls (Jingle - XEP-0166)
- Push notifications
- PWA con service worker
- Dark mode nativo
- Emoji picker
- Markdown support

---

## [0.9.0] - 2025-11-30

### Aggiunte
- **Sistema vCard completo**: Supporto per avatar, nomi display e informazioni profilo
- **Pagina profilo utente**: Interfaccia per modifica profilo e avatar
- **Pull-to-refresh**: Gesto di refresh per conversazioni e chat
- **Message Archive Management**: Supporto XEP-0313 per storico messaggi
- **Paginazione messaggi**: Caricamento lazy con scroll infinito
- **Ricerca conversazioni**: Filtro in tempo reale
- **Typing indicators**: Indicatori di scrittura in corso
- **Presence management**: Gestione stato presenza utenti

### Modifiche
- **Refactoring Flexbox First**: Migrazione completa da CSS Grid a Flexbox per layout responsive
  - Convertiti 3 layout in `App.css`
  - Conformità 100% alle design guidelines
  - Migliorate performance rendering
  
- **Scrollable Containers**: Creazione classe utility `.scrollable-container`
  - Riduzione CSS ridondante del 71% (25 righe)
  - Centralizzazione gestione scroll in singola classe
  - Aggiornati 4 componenti TSX e 4 file CSS
  - Bundle size ridotto di 550 bytes
  
- **Ottimizzazione sincronizzazione**: Strategia cache-first per apertura istantanea chat
  - Apertura chat < 100ms grazie a cache locale
  - Riduzione query MAM del 80%
  - Migliorata gestione offline

### Corretti
- **Profile Save Error**: Migliorata gestione errori con messaggi specifici
  - Validazione preventiva dati
  - Gestione errori XMPP granulare (not-authorized, forbidden, service-unavailable)
  - Logging dettagliato per debug
  
- **vCard Photo Base64**: Risolto timeout salvataggio foto profilo
  - Corretto formato dati da Buffer a stringa base64
  - Ridotto tempo salvataggio da 15s+ a ~105ms
  - Testato con PNG e JPEG
  
- **Profile Scroll Conflict**: Risolto conflitto scroll tra pagina e contenitore
  - Riprogettata architettura layout ProfilePage
  - Separazione responsabilità scroll
  - Fix overflow e touch-action
  
- **Race Conditions Messaggi**: Eliminati messaggi duplicati
  - Implementato merge intelligente messaggi
  - De-duplicazione basata su messageId
  - Gestione corretta transizioni stato
  
- **Memory Leak**: Prevenuti setState dopo unmount
  - Aggiunto flag isMountedRef
  - Cleanup corretto in useEffect
  - Eliminati warning React
  
- **Paginazione MAM**: Corretta gestione token RSM
  - Uso corretto di beforeToken/afterToken
  - Persistenza token per conversazione
  - Fix loadMore messaggi vecchi
  
- **Performance getAll()**: Ottimizzate query database
  - Aggiunto index by-tempId
  - Ridotte query da O(n) a O(1)
  - Migliorata scalabilità con migliaia di messaggi

- **WebSocket URL Fallback**: Corretti URL alternativi connessione XMPP
  - Fix path `/ws` → `/websocket` per conversations.im
  - Aggiunto supporto porta 443 esplicita
  - Migliorata robustezza connessione

### Sicurezza
- **Validazione Input**: Aggiunta validazione dati vCard e messaggi
- **Error Boundary**: Implementato React Error Boundary per gestione crash
- **Sanitizzazione**: Sanitizzazione input utente per prevenire XSS

### Documentazione
- **Riorganizzazione completa**: Struttura docs/ con categorie logiche
  - `architecture/` - Documentazione architetturale
  - `implementation/` - Dettagli implementativi
  - `design/` - Design e UI/UX
  - `guides/` - Guide pratiche
  - `decisions/` - Architecture Decision Records
  - `fixes/` - Bug fix e ottimizzazioni
  - `archive/` - Documenti storici
  
- **INDICE.md**: Indice navigabile completo con link rapidi
- **README principale**: Espanso con guida completa al progetto
- **JSDoc completo**: Documentazione funzioni principali
- **Guide implementazione**: 
  - Sistema login
  - Sistema sincronizzazione
  - Scrollable containers
  - Routing system
  
- **Revisioni tecniche**:
  - Revisione ingegnerizzazione completa
  - Analisi problemi critici
  - Metriche code quality

---

## [0.5.0] - 2025-01-27

### Aggiunte
- **Utility Functions**: Moduli centralizzati per funzioni comuni
  - `utils/jid.ts` - Gestione JID (normalizeJid, parseJid, isValidJid)
  - `utils/date.ts` - Formattazione date (formatDateSeparator, formatMessageTime)
  - `utils/message.ts` - Gestione messaggi (generateTempId, mergeMessages, truncateMessage)
  
- **Costanti Centralizzate**: File `config/constants.ts` espanso
  - Costanti paginazione (PAGE_SIZE, MAX_RESULTS)
  - Timeout e limiti
  - Storage keys
  - Message status
  
- **Error Boundary**: Componente per gestione errori React
  - UI fallback user-friendly
  - Logging errori in development
  - Opzioni di recovery

### Modifiche
- **Type Safety**: Migliorata type safety complessiva
  - Rimossi type assertions non sicure
  - Uso di `as const` per costanti
  - Tipi espliciti per utility functions
  
- **Code Organization**: Migliorata organizzazione codice
  - Eliminata duplicazione tra servizi
  - Separazione chiara utilities/services/components
  - Import organizzati e coerenti

### Documentazione
- **REVISIONE_INGEGNERIZZAZIONE.md**: Documento completo revisione tecnica (~328 righe)
- **SOMMARIO_MIGLIORAMENTI.md**: Riepilogo miglioramenti implementati

---

## [0.3.0] - 2024-11-30

### Aggiunte
- **Login System**: Sistema login con popup glassmorphism
- **XMPP Connection**: Integrazione Stanza.js completa
- **Conversations List**: Lista conversazioni con avatar e preview
- **Chat Interface**: UI chat Telegram-style con dark mode
- **Local Database**: IndexedDB per cache completa
- **Real-time Messaging**: Invio e ricezione messaggi in tempo reale
- **Optimistic Updates**: Feedback immediato per azioni utente

### Architettura
- **XmppContext**: Context React per stato XMPP globale
- **Services Layer**: Servizi per XMPP, database, messaggi, conversazioni
- **Offline-First**: Strategia cache-first per performance
- **HashRouter**: Routing client-side per compatibilità hosting statico

### Design
- **Brand Identity**: Definito colore istituzionale #2D2926 (Dark Charcoal)
- **Design System**: Linee guida Flexbox First
- **Responsive**: Layout mobile-first responsive
- **Accessibility**: WCAG 2.1 AA compliance

---

## [0.1.0] - 2024-10-15

### Aggiunte
- Setup iniziale progetto React + TypeScript + Vite
- Configurazione ESLint e TypeScript strict mode
- Struttura base cartelle (components, pages, services, contexts)
- GitHub Pages deployment workflow
- README e documentazione base

---

## Note Storiche

Documenti archiviati pre-0.9.0 consolidati in questo changelog. Documenti specifici di sessioni di lavoro sono stati archiviati in `docs/archive/old-docs/`.

---

**Ultimo aggiornamento**: 2025-12-06
