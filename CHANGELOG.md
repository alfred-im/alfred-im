# Changelog Tecnico

Modifiche rilevanti al progetto per tracciare evoluzione tecnica e decisioni implementative. Questo documento è per riferimento interno AI, non per utenti esterni.

---

## [3.0.0-alpha] - 2026-06-24

### Aggiunto
- **ADR bridge stateless** (D-051): bridge senza stato di business; verità su Supabase — `docs/decisions/bridge-stateless.md`
- **Client Flutter** (`client/`): UI mock chat, tema Alfred, layout responsive
- **Deploy GitHub Pages**: workflow Flutter, URL https://alfred-im.github.io/XmppTest/
- **Scaffold multi-piattaforma**: web, Android, iOS, Linux, macOS, Windows

### Rimosso
- **`web-client/`** React da `main` (recuperabile: tag `legacy/web-client-final` @ `6e792eb`)
- Workflow Pages per build React (sostituito da Flutter)

### Documentazione
- Aggiornati PROJECT_MAP, README, INDICE, discovery doc, client/README

---

## [Unreleased]

### Alpha Flutter — PR #153 (condivisione posizione statica)

- **`content_type=location`**: colonne `latitude`/`longitude` in `messages`; RPC `send_message_to_profile` a 10 parametri
- **Invio**: pin in `ChatInputBar` → overlay full-screen → stream GPS → anteprima mappa OSM (`flutter_map`) → conferma **Invia posizione**
- **Ricezione**: `LocationMessageContent` — tile OSM in bolla, tap apre OpenStreetMap
- **Inbox**: preview `📍 Posizione` (`format_location_preview`)
- **Coda**: `OutboundContentKind.location` con coordinate in retry
- **CI**: retry deploy GitHub Pages (fino a 3 tentativi su errori transitori)
- **Doc**: `docs/implementation/location-sharing.md`; `alpha-full-stack.md` §2.13
- **Migrazioni**: `20260702120000`, `20260702120100`

### Alpha Flutter — PR #152 (multi-account: una GoTrue attiva)

- **Runtime**: al massimo una `AccountSession` GoTrue in RAM (account in focus); manifest elenca tutti gli account aperti
- **`setFocus`**: dispose sessione corrente (conserva `alfred_auth_{userId}`), restore nuovo account da manifest, `inbox.load()`
- **Fix web**: evita collisioni `BroadcastChannel` auth tra client GoTrue paralleli (inbox JWT sbagliato al switch)
- **Doc**: `docs/fixes/multi-account-single-active-gotrue-pr152.md`; ADR e implementation multi-account aggiornati
- **E2E**: `multi-account-messages.spec.ts` — gate DB + ricezione UI dopo switch

### Alpha Flutter — PR #147 (persistenza dichiarativa multi-account)

- **`AccountSession.persistOpenAccount`**: token dalla risposta HTTP / evento auth, non da `currentSession` globale
- **`AccountManager`**: niente `_persistAllOpenAccounts`; `upsertAccount` / `removeAccount` per entry
- **F5**: manifest = unica verità; restore solo account in focus (completato con #152 per runtime)
- **Doc**: `docs/implementation/multi-account-persistence-redesign.md` — implementato

### Alpha Flutter — PR #143 (multi-account: logout locale, chat, persistenza)

- **Logout locale**: `AccountSession.close()` senza `signOut` GoTrue — solo `alfred_auth_{userId}`
- **View per account**: `Map<userId, AccountViewState>`; `sanitizedForAccount()`; niente reset globale su `setFocus`
- **Inbox lifecycle**: `ListenableProxyProvider` con dispose noop — `InboxController` owned da `AccountSession`
- **Persistenza**: `_persistAllOpenAccounts()` + `saveAllAccounts` atomico; write lock storage; restore solo errori auth definitivi
- **Test**: 9 casi regressione multi-account (mock) — `verify.sh` 59 test
- **Harness**: `integration-multi-account.sh`, `diagnose-test-env.sh`, `reset-chrome-cdp.sh`
- **Doc**: `docs/fixes/multi-account-chat-persistence-pr143.md`, `SESSION_HANDOFF.md` aggiornato
- **Nota**: validazione browser utente ancora negativa al handoff — gap e2e documentato

### Alpha Flutter — PR #142 (auth bootstrap + PKCE)

- **Rimosso** `bootstrap.auth.signOut()` dopo login/signup — non revoca più il refresh token condiviso con il client dedicato
- **`EphemeralPkceStorage`**: PKCE su client bootstrap effimero (recupero password senza crash null)
- **Test**: `password_reset_live_test.dart` (tag `live`), `account_session_bootstrap_test.dart`
- **Doc**: `docs/fixes/auth-bootstrap-gotrue-revoke.md`, `docs/SESSION_HANDOFF.md`, `docs/AGENT_DEBUG_ACCOUNTS.md`
- **Topic aperto**: logout solo dispositivo — `docs/decisions/single-device-logout-open.md`

### Alpha Flutter — PR #141 (add-account parziale, superseded da #142 su signOut)

- **`_sessionFromAuthResponse`**: adozione sessione dedicata con access+refresh senza `restore()` immediato
- **Residuo pre-#142**: `signOut` bootstrap nel `finally` ancora presente su main fino a merge #142

### Alpha Flutter — PR #140 (multi-account sessioni parallele)

- **Modello**: account aperto = sessione Supabase viva + realtime inbox; non bookmark + `setSession`
- **`AccountManager` / `AccountSession`**: un `SupabaseClient` per account; servizi dati per-client
- **`OpenAccount`**: sostituisce `SavedAccount` (stesso payload storage)
- **Shell**: `HomeScreen` sempre visibile; `AuthOverlay` semi-trasparente (0 account = obbligatorio; aggiungi = chiudibile)
- **Focus**: `setFocus` — switch istantaneo, nessuna ri-autenticazione
- **Rimossi**: `AuthService`, gate `AppShell` auth vs home, `switchAccount` con `setSession`
- **ADR**: `docs/decisions/multi-account-parallel-sessions.md`
- **Design**: `docs/design/auth-overlay-shell.md`
- **Implementazione**: `docs/implementation/multi-account-client.md`

### Documentazione (2026-06-28 — rimozione legacy React/XMPP)

- Eliminati doc architettura/implementazione/fix relativi al client React rimosso da `main`
- `PROJECT_MAP.md` riscritto — solo stack Flutter + Supabase attivo
- Codice storico recuperabile solo via tag git `legacy/web-client-final` (non documentato nel repo)

### Documentazione (2026-06-28 — sync post-merge #126–#132)

- Allineati `PROJECT_MAP.md`, `README.md`, `docs/INDICE.md`, `alpha-full-stack.md` — stato PR e date (tutto mergiato su `main`)

### Alpha Flutter — PR #132 (ricerca on-demand inbox)

- **`InboxPanel`**: barra «Cerca messaggi» nascosta di default; icona lente apre con focus; chiusura via `dismissSearch()` (toggle lente + `TapRegion.onTapOutside`); filtro azzerato alla chiusura
- **Layout**: mobile = lente in header accanto a Contatti; desktop = riga «Conversazioni» + lente
- **`HomeScreen`**: `ValueKey(userId)` su `InboxPanel` — reset stato ricerca al cambio account
- **Design**: `docs/design/inbox-search-toggle.md`

### Alpha Flutter — PR #131 (sidebar logout)

- **`AccountSidebar`**: rimossa spunta verde fissa sull'account attivo; logout spostato in card profilo (icona a destra del nome)
- Rimossa voce «Esci» in fondo alla sidebar (logout unico punto di uscita nella card)

### Alpha Flutter — PR #130 (inbox solo messaggi)

- **Drop `inbox_threads`**: inbox = `list_inbox()` aggregazione on-read su `messages` (non vista materializzata, non cache con FK)
- **RPC peer-based**: `list_peer_messages`, `mark_peer_read` (no `thread_id`)
- **Client**: `ChatPeer` per account; niente bozza/ComposeTarget/InboxThread
- Migrazione `20260627230000_messages_only_inbox.sql`

### Alpha Flutter — PR #129 (messaggistica per indirizzo, iterazione precedente)
- **Modello message-centric**: `inbox_threads`, messaggi con `sender_id` + `recipient_profile_id`; drop `conversations`
- **RPC**: `list_inbox`, `list_thread_messages`, `send_message_to_profile`, `find_profile_by_username`, `mark_thread_read`
- **Client**: `InboxController`, bozza compose (FAB → username), invio senza rubrica
- **Fix invio**: rimosso overload duplicato `send_message_to_profile(uuid,text,text)` — PostgREST HTTP 300
- **ADR**: `docs/decisions/address-based-messaging.md`

### CI / deploy Alpha (2026-06-27)
- **Workflow unificato `deploy-alpha`**: ogni PR su `main` (path `client/**`) e ogni push a `main` pubblicano su https://alfred-im.github.io/XmppTest/ — ambiente **sviluppo**, non produzione
- Rimossi job `deploy-preview` / `deploy-prod`; concurrency `pages-alpha`
- **Vincolo GitHub**: Environment `github-pages` → *Deployment branches: All branches* (default solo `main` → errore `environment protection rules` su PR)

### Alpha Flutter — PR #126 (note vocali in chat)
- **`content_type=voice`**: `duration_seconds`, `media_mime`, `media_size_bytes`, `media_url` — formato canonico **WebM/Opus** (`audio/webm`)
- Migrazioni `20260627120000` + `20260627120100` — applicate su progetto cloud
- Client: `VoiceRecordingService`, transcode IO (FFmpeg), `VoiceMessageContent` (waveform + `just_audio`), gesti hold/swipe in `ChatInputBar`
- **`OutboundMessageQueue`**: retry client unificato per testo, GIF e voice (persistenza + «Riprova invio»)
- Bucket `chat-media`: esteso a `audio/webm`, limite 15 MB
- Preview inbox: `🎤 m:ss`

### Alpha Flutter — PR #127 (processo analyze, branch separata)
- **`client/scripts/verify.sh`**: `pub get` → `analyze` → `test` (opzionale `--build`)
- Allineamento `.cursor-rules.md` e CI al gate `flutter analyze` (zero issue, incluso livello `info`)

### Documentazione (2026-06-27)
- **ADR** [no-internal-external-chat-distinction.md](docs/decisions/no-internal-external-chat-distinction.md) — vietata distinzione chat interna/esterna a tutti i livelli (PR #124)
- **Design** [conversation-bottom-anchor.md](docs/design/conversation-bottom-anchor.md) — specifica aggancio al fondo conversazione

### Alpha Flutter — PR #125 (aggancio al fondo)
- **`AnchoredMessageList`**: `ListView` `reverse: true`, soglia aggancio 48 px, pulsante riaggancio + badge
- **`ConversationScrollAnchor`**: logica pura in `utils/conversation_scroll_anchor.dart`
- Integrato in `ChatPanel` — comportamento unico per tutte le conversazioni (ADR chat unificate)
- Rimosso sottotitolo header dipendente da `protocol`
- Test: `conversation_scroll_anchor_test.dart`, `anchored_message_list_test.dart`

### Documentazione (2026-06-24 — sync PR Alpha #108–#114)
- **`docs/architecture/alpha-pr-registry.md`**: registro PR → feature → documenti da aggiornare
- **`docs/fixes/flutter-inbox-stability.md`**: fix PR #113/#114 (race auth + ChangeNotifierProxyProvider)
- Allineati PROJECT_MAP, CHANGELOG, INDICE, README, `alpha-full-stack.md`, discovery doc

### Alpha Flutter — PR #115 (GIF in chat)
- **Messaggi GIF**: `messages.content_type` (`text`|`gif`), `messages.media_url`
- Migrazione `20260624230000_message_gif_support.sql` — applicata su progetto cloud
- Storage bucket `chat-media` (solo `image/gif`, 10 MB, RLS per cartella utente)
- Client: `MessageMediaService`, picker GIF in `ChatInputBar`, rendering in `MessageBubble`

### Alpha Flutter — PR #114 (fix provider listen)
- **`ChangeNotifierProxyProvider`** al posto di `ProxyProvider` per Conversations/Contacts/Profile
- Test widget `conversations_provider_listen_test.dart` + e2e `inbox-load.spec.ts`

### Alpha Flutter — PR #113 (fix inbox auth race)
- **`waitForSupabaseSessionReady()`** dopo `Supabase.initialize` prima delle RPC
- `ConversationsController`: realtime dopo primo load; timeout 30s; UI errore + Riprova
- Gate `sessionReady` su `ChangeNotifierProxyProvider` in `main.dart`

### Alpha Flutter — PR #112 (inbox performance)
- **RPC `list_conversations()`**: inbox completa in un round-trip (display name server-side)
- Migrazione `20260624220000_list_conversations_rpc.sql` — applicata su progetto cloud
- Client: `ConversationService` usa RPC; `Conversation.fromListRpcRow`

### Alpha Flutter — PR #111 (multi-account)
- Switch account: persist refresh token; `tokenRefreshed`; flusso **Aggiungi account**
- Ripristino sessione se switch fallisce

### Alpha Flutter — PR #110 (GitHub Pages)
- Script passkeys `bundle.js` in `client/web/index.html` — fix schermo bianco

### Alpha Flutter — PR #109 (app completa + piattaforma)
- Client Flutter collegato a Supabase: auth, contatti, chat realtime, profilo
- Schema dominio `20260624200000_alfred_domain_schema.sql` + RLS + RPC base
- Documentazione: `docs/architecture/alpha-full-stack.md`

### Alpha Flutter — PR #108 (UI chat base)
- Layout conversazioni + chat, tema Alfred, workflow deploy Pages

---

### Legacy React (pre-3.0.0-alpha) — storico

Le voci sotto riguardano il client React (`legacy/web-client-final`), non il Flutter su `main`.

### Corretti (2026-06-24 — multi-account XMPP)
- **Isolamento storage per account XMPP** (v2.2):
  - Un IndexedDB per JID: `conversations-db-{account}`
  - `account-session.ts`: `switchAccountContext()`, `onAccountChanged()`
  - Migrazione automatica da DB legacy condiviso `conversations-db`
  - Storico locale **conservato al logout** (nessun wipe)
- **Cursor project rules**: `.cursor/rules/main.mdc` — vincolo lettura `.cursor-rules.md`
- **Documentazione**: `docs/fixes/account-storage-isolation.md`; aggiornati PROJECT_MAP, INDICE, README, sync-system-complete

### Corretti
- **Cambio account**: conversazioni e messaggi del precedente account non più visibili dopo logout/login con altro JID
- **ConversationsContext**: ricarica da DB dell'account attivo (`accountJid` da ConnectionContext)
- **Memoria React**: reset virtual messages e cache UI su `onAccountChanged` senza cancellare IndexedDB

### Rimosso (approccio scartato)
- ~~Wipe IndexedDB al logout~~ — incompatibile con storico lungo; sostituito da DB per account

### Aggiunto (batch v4.0 — giugno 2026)
- **Spunte WhatsApp 3 livelli**: ✓ inviato, ✓✓ grigie (XEP-0184), ✓✓ blu (XEP-0333)
- **Virtual UI + MAM-only DB**: listener campanello, outbox, origin-id canonico
- **XEP-0184**: `receipt request` in invio, listener `receipt`, overlay `deliveredUi`
- **Documentazione**: `message-states.md` v2.1, `delivery-receipts-xep-0184.md`, `sync-system-complete.md` v4.0
- **Sync Boundary Handoff**: all'avvio salva momento T, attiva listener da T, sync MAM fino a T + 5s overlap
- **Allineamento documentazione**: PROJECT_MAP, README, WISHLIST, architecture README aggiornati a v4.0

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
- PWA con service worker migliorato
- Dark mode nativo
- Emoji picker
- Markdown support
- XEP-0280 Message Carbons (multi-device)

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

Documenti storici pre-0.9.0 consolidati in questo changelog. Documentazione client React rimossa dal repo (2026-06-28); codice storico solo su tag `legacy/web-client-final`.

---

**Ultimo aggiornamento**: 2025-12-06
