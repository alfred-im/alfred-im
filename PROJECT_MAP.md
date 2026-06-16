# Alfred - Mappa Completa del Progetto

**Ultimo aggiornamento**: 2026-06-16 (Sync Boundary Handoff)  
**Versione**: 1.1.0 (XEP-0333 Chat Markers)

---

## 📋 Indice

1. [Panoramica Progetto](#panoramica-progetto)
2. [Architettura](#architettura)
3. [Struttura File e Responsabilità](#struttura-file-e-responsabilità)
4. [Dipendenze](#dipendenze)
5. [Entrypoint](#entrypoint)
6. [Servizi Esterni](#servizi-esterni)
7. [Build e Testing](#build-e-testing)
8. [Database e Storage](#database-e-storage)
9. [Stato Corrente](#stato-corrente)

---

## 📌 Panoramica Progetto

**Alfred** è un client web XMPP moderno per messaggistica istantanea, basato su React e TypeScript.

### Caratteristiche Principali
- **Offline-First**: Cache locale completa con IndexedDB
- **Performance**: Apertura chat < 100ms
- **Modern Stack**: React 19, TypeScript 5, Vite 7
- **XMPP Protocol**: Stanza.js 12.21.x con supporto MAM (XEP-0313)
- **Push Notifications**: XEP-0357 con abilitazione automatica
- **Progressive Web App**: Service Worker per offline support

### Tecnologie Core
| Categoria | Tecnologia | Versione |
|-----------|------------|----------|
| Frontend | React | 19.2.0 |
| Language | TypeScript | 5.9.3 |
| Build Tool | Vite | 7.2.4 |
| Router | React Router | 7.9.6 |
| XMPP | Stanza.js | 12.21.0 |
| Database | IndexedDB (idb) | 8.0.3 |
| Testing | Playwright | 1.57.0 |

---

## 🏗️ Architettura

### Layer Architecture

```
┌─────────────────────────────────────┐
│         UI Layer (Pages)            │
│  ChatPage, ConversationsPage,       │
│  ProfilePage                        │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│      Components Layer               │
│  LoginPopup, ConversationsList,     │
│  PushNotificationSettings           │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│      Context Layer (State)          │
│  XmppContext, ConversationsContext, │
│  MessagingContext, AuthContext,     │
│  ConnectionContext                  │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│       Services Layer                │
│  xmpp.ts, messages.ts,              │
│  conversations.ts, sync-initializer.ts, │
│  push-notifications.ts              │
└──────────────┬──────────────────────┘
               │
       ┌───────┴───────┐
       │               │
┌──────▼──────┐ ┌─────▼──────┐
│ Repositories│ │  Utils     │
│ (Data Layer)│ │  (Helper)  │
└─────────────┘ └────────────┘
       │               │
       └───────┬───────┘
               │
    ┌──────────▼────────────┐
    │  XMPP Server + IndexedDB  │
    └───────────────────────────┘
```

### Principi Architetturali
1. **Separation of Concerns**: UI, State, Business Logic, Data Access separati
2. **Cache-First**: Mostra sempre prima i dati locali (IndexedDB)
3. **Minimal Server Queries**: Massimizza cache, minimizza query XMPP
4. **Unidirectional Data Flow**: Props down, Events up
5. **Server as Source of Truth**: Database locale è SOLO sincronizzazione dal server XMPP
   - Il server XMPP è l'unica fonte di verità
   - Database locale è cache/sincronizzazione per performance
   - Direzione sync: DAL server AL database locale (mai il contrario)
   - Modifiche: sempre tramite server XMPP, poi sincronizzare localmente
   - NON modificare mai direttamente il database locale
   - Benefici: Coerenza dati, sync multi-device, affidabilità, performance
6. **Rendering Fa Le Scelte**: La UI decide cosa e come mostrare basandosi sui dati grezzi
   - Dati salvati esattamente come arrivano dal server (no trasformazioni in DB)
   - Logica di presentazione (filtri, combinazioni, calcoli) avviene durante rendering
   - Esempio: marker XEP-0333 salvati come messaggi separati, combinati visualmente nel rendering

### Strategia Chat Markers (XEP-0333)

**Implementazione spunte di lettura stile WhatsApp/Telegram**

#### Architettura Dati

**Messaggi nel DB**:
- Messaggi testuali: `body: "testo"`, `markerType: undefined`
- Marker: `body: ""`, `markerType: 'displayed'|'acknowledged'`, `markerFor: messageId`

**Fonte dati**:
- Sincronizzazione MAM: scarica messaggi testuali E marker insieme nella stessa query
- Eventi real-time: marker `displayed`/`acknowledged` arrivano come eventi separati
- Invio marker: `client.markDisplayed()` invia al server, poi ritorna via MAM

**Storage**:
- Tutti salvati come messaggi nel DB (`messages` object store)
- Marker hanno campi speciali: `markerType` e `markerFor`
- NO modifica DB: marker salvati esattamente come arrivano dal server

#### Strategia Rendering

**Ciclo rendering messaggi** (`MessageItem.tsx`):

```
Per ogni messaggio nell'array:

1. HA body con testo?
   → SÌ: Messaggio normale
      - Cerca marker con markerFor === messageId
      - Determina spunta: marker?.markerType || message.status
      - Renderizza messaggio CON spunta appropriata
   
2. È un marker (body vuoto + markerType)?
   → SÌ: return null (nascosto, applicato solo visivamente)
   
3. Altro (body vuoto, no markerType)?
   → Messaggio sconosciuto, renderizza per debug
```

**Logica spunte**:
- `status: 'sent'` → ✓ singola grigia
- `markerType: 'displayed'` → ✓✓ doppie grigie
- `markerType: 'acknowledged'` → ✓✓ doppie blu

**Priorità**: Se esiste marker per un messaggio, `markerType` sovrascrive `message.status`.

**Vantaggi strategia**:
- DB contiene dati grezzi esattamente come dal server
- Nessuna modifica/mutazione dei dati
- Logica presentazione separata dai dati
- Coerenza con principio "Rendering Fa Le Scelte"

---

## 📂 Struttura File e Responsabilità

### Root Directory (`/workspace`)

```
/workspace/
├── .cursor-rules.md          # Regole di sviluppo per AI assistant
├── .github/                   # GitHub Actions per deployment
│   └── workflows/
│       └── deploy-pages.yml   # Deploy automatico su GitHub Pages
├── docs/                      # Documentazione tecnica per AI (35 file)
│   ├── architecture/          # Analisi architetturali
│   ├── implementation/        # Dettagli implementativi
│   ├── design/                # Principi design e brand identity
│   ├── decisions/             # Architecture Decision Records
│   ├── fixes/                 # Analisi bug fix
│   └── archive/               # Ricerca XMPP e documenti storici
├── web-client/                # Applicazione React principale
├── README.md                  # Documentazione principale
├── CHANGELOG.md               # Change log del progetto
├── LICENSE                    # Licenza MIT
├── TEST_CREDENTIALS.md        # Credenziali di test
└── PROCEDURA_REVISIONE_GENERALE.md  # Procedura di revisione
```

### Web Client (`/workspace/web-client`)

#### **Configurazione e Setup**
```
web-client/
├── package.json               # Dipendenze e script npm
├── vite.config.ts             # Configurazione build Vite
├── tsconfig.json              # Configurazione TypeScript
├── tsconfig.app.json          # TypeScript per app
├── tsconfig.node.json         # TypeScript per Node
├── eslint.config.js           # Configurazione ESLint
├── index.html                 # HTML entry point
└── public/                    # Asset statici
    ├── manifest.json          # PWA manifest
    └── sw.js                  # Service Worker per offline support
```

#### **Source Code (`src/`)**

##### **Entrypoint**
- `main.tsx` - **ENTRYPOINT PRINCIPALE**
  - Inizializzazione React
  - Inizializzazione Debug Logger (intercetta console.log)
  - Registrazione Service Worker
  - Gestione touch events (blocco overscroll nativo, pinch-zoom)
  - Gestione orientamento schermo

##### **App Core**
- `App.tsx` - **ROOT COMPONENT**
  - Setup Context Providers
  - Router principale (HashRouter)

##### **Pages (`pages/`)**
Pagine principali dell'applicazione (route)

| File | Responsabilità | Route |
|------|----------------|-------|
| `ConversationsPage.tsx` | Lista conversazioni con ricerca | `#/` |
| `ChatPage.tsx` | Vista chat 1-to-1 con messaggi e invio | `#/chat/:jid` |
| `ProfilePage.tsx` | Profilo utente e modifica vCard | `#/profile` |

##### **Components (`components/`)**
Componenti riutilizzabili

| File | Responsabilità |
|------|----------------|
| `AppInitializer.tsx` | Inizializzazione app e auto-login |
| `LoginPopup.tsx` | Popup di login con glassmorphism |
| `ConversationsList.tsx` | Lista conversazioni con avatar e preview |
| `NewConversationPopup.tsx` | Popup per nuova conversazione |
| `PushNotificationsSettings.tsx` | Configurazione push notifications |
| `PushNotificationStatus.tsx` | Status indicator push notifications |
| `SplashScreen.tsx` | Schermata di caricamento iniziale |
| `ErrorBoundary.tsx` | Gestione errori React |
| `DebugLogPopup.tsx` | Popup per visualizzare console logs intercettati |

##### **Contexts (`contexts/`)**
State management globale con React Context

| File | Responsabilità | State Gestito |
|------|----------------|---------------|
| `ConnectionContext.tsx` | **CONTEXT PRINCIPALE** - Connessione XMPP e auto-login all'avvio | Client, isConnected, isConnecting, JID |
| `AuthContext.tsx` | Gestione credenziali (salvataggio/caricamento) | JID, Password, Login status |
| `ConversationsContext.tsx` | Lista conversazioni (cache locale) | Conversations[], `refreshConversation` |
| `MessagingContext.tsx` | Gestione messaggi real-time (inclusi marker XEP-0333) | Message handlers, Marker handlers |

##### **Services (`services/`)**
Business logic e comunicazione con XMPP server

**ARCHITETTURA "SYNC-ONCE + LISTEN"** (implementata 15 dicembre 2025):
- **sync-initializer.ts** - UNICO punto di sincronizzazione (all'avvio)
- **sync-boundary.ts** - Handoff sync/listener: salva momento T, attiva listener, MAM fino a T
- **sync-status.ts** - Pattern Observer per stato sync (UI indicators)
- Tutti gli altri services sono "listener-only" durante utilizzo

##### **Services Core**
Business logic e integrazione servizi esterni

| File | Responsabilità | Dipendenze |
|------|----------------|------------|
| `sync-initializer.ts` | **SYNC ALL'AVVIO** (full o incremental, MAM fino a boundary T) | XMPP, Repositories |
| `sync-boundary.ts` | **HANDOFF SYNC/LISTENER** (momento T, gate listener real-time) | - |
| `sync-status.ts` | **Observer** per stato sync globale | - |
| `xmpp.ts` | **CORE XMPP** - Connessione, discovery, login/register | Stanza.js |
| `messages.ts` | Gestione messaggi (invio, NO SYNC) | XMPP, Repositories |
| `conversations.ts` | Gestione conversazioni e roster | XMPP, IndexedDB |
| `conversations-db.ts` | Database IndexedDB per conversazioni | idb |
| `vcard.ts` | Gestione vCard (avatar, profilo) | XMPP XEP-0054 |
| `push-notifications.ts` | Push Notifications XEP-0357 | Service Worker, XMPP |
| `auth-storage.ts` | Storage credenziali per auto-login (localStorage) | localStorage API |
| `debug-logger.ts` | Intercettazione e raccolta console logs | Browser Console API |

##### **Repositories (`services/repositories/`)**
Data Access Layer per IndexedDB

**ARCHITETTURA "SYNC-ONCE + LISTEN"**:
- MessageRepository usa **Pattern Observer** per notifiche real-time
- MetadataRepository gestisce **marker sync** (lastRSMToken, isInitialSyncComplete)

| File | Responsabilità | Ruolo Architettura |
|------|----------------|-------------------|
| `ConversationRepository.ts` | CRUD conversazioni su IndexedDB | Cache locale, no sync |
| `MessageRepository.ts` | CRUD messaggi + **Observer pattern** | Real-time updates, notifiche UI |
| `VCardRepository.ts` | CRUD vCard cache | Cache profili contatti |
| `MetadataRepository.ts` | CRUD metadata sync (**marker RSM**) | Tracking sync incrementale |
| `index.ts` | Export centrale repositories | - |

##### **Hooks (`hooks/`)**
Custom React Hooks

| File | Responsabilità | Note |
|------|----------------|------|
| `useMessages.ts` | Hook per gestione messaggi in chat (cache-only) | Observer pattern |
| `useBackButton.ts` | Hook per back button Android | - |

##### **Utils (`utils/`)**
Utility functions

| File | Responsabilità |
|------|----------------|
| `jid.ts` | Parse e validazione JID XMPP |
| `date.ts` | Formattazione date e timestamp |
| `message.ts` | Utility per messaggi (truncate, format) |
| `image.ts` | Utility per immagini (resize, convert) |

##### **Config (`config/`)**
- `constants.ts` - **TUTTE LE COSTANTI CONFIGURABILI**
  - XMPP server defaults
  - UI configuration
  - Pagination settings
  - Timeouts
  - Storage keys

---

## 📦 Dipendenze

### Dipendenze di Produzione (`dependencies`)

| Package | Versione | Uso |
|---------|----------|-----|
| `react` | 19.2.0 | UI Framework |
| `react-dom` | 19.2.0 | React rendering |
| `react-router-dom` | 7.9.6 | Routing (HashRouter) |
| `stanza` | 12.21.0 | **CORE** - XMPP client library |
| `idb` | 8.0.3 | **CORE** - IndexedDB wrapper |
| `events` | 3.3.0 | Event emitter polyfill |
| `node-fetch` | 3.3.2 | Fetch polyfill per testing |

### Dipendenze di Sviluppo (`devDependencies`)

| Package | Versione | Uso |
|---------|----------|-----|
| `typescript` | 5.9.3 | Type checking |
| `vite` | 7.2.4 | Build tool e dev server |
| `@vitejs/plugin-react` | 5.1.1 | React plugin per Vite |
| `eslint` | 9.39.1 | Linting |
| `@playwright/test` | 1.57.0 | E2E testing |
| `jsdom` | 27.2.0 | DOM testing |

### Dipendenze Critiche

⚠️ **ATTENZIONE**: Questi package sono CORE per il funzionamento:
1. **stanza** (12.21.0) - XMPP protocol implementation
2. **idb** (8.0.3) - Offline-first data persistence
3. **react-router-dom** (7.9.6) - Navigation

Non aggiornare queste versioni senza testing completo.

---

## 🚀 Entrypoint

### 1. **Entry Point HTML**
- **File**: `/workspace/web-client/index.html`
- **Responsabilità**: HTML root, link a `main.tsx`

### 2. **Entry Point JavaScript**
- **File**: `/workspace/web-client/src/main.tsx`
- **Responsabilità**: 
  - React initialization
  - Service Worker registration
  - Global event handlers (touch, zoom, orientation)

### 3. **App Root Component**
- **File**: `/workspace/web-client/src/App.tsx`
- **Responsabilità**:
  - Context Providers setup
  - Router configuration (HashRouter)
  - Global error boundary

### 4. **Service Worker**
- **File**: `/workspace/web-client/public/sw.js`
- **Responsabilità**:
  - Offline caching
  - Push notifications handling

### Flow di Inizializzazione ("Sync-Once + Listen")

```
index.html
  → main.tsx (React.render)
    → AppInitializer
        1. Salva boundary T (momento corrente)
        2. Attiva listener real-time (da T in poi → DB)
        3. Sync MAM solo passato (end = T)
      → App.tsx (Contexts + Router)
        → ConversationsPage | ChatPage | ProfilePage
          └─→ LISTEN continua (messaggi da T in poi)
```

**Handoff esplicito**: sync copia il passato (MAM fino a T + 5s di margine), listener copia il futuro (da T). Sovrapposizione intenzionale ai bordi; de-duplicazione per messageId.

**Novità v3.0**: `AppInitializer` gestisce sync iniziale PRIMA di renderizzare l'app normale.

---

## 🌐 Servizi Esterni

### 1. **XMPP Server**

**Server di Default**:
- **Domain**: `jabber.hot-chilli.net`
- **WebSocket**: `wss://jabber.hot-chilli.net:5281/xmpp-websocket`

**Discovery Automatico**:
- XEP-0156 (host-meta discovery) implementato in `xmpp.ts`
- Fallback automatico su pattern comuni se discovery fallisce

**Protocolli XMPP Supportati**:
| XEP | Nome | Implementazione |
|-----|------|-----------------|
| XEP-0313 | Message Archive Management (MAM) | `sync-initializer.ts`, `conversations.ts` |
| XEP-0059 | Result Set Management (RSM) | `sync-initializer.ts` (tokens) |
| XEP-0054 | vCard-temp | `vcard.ts` |
| XEP-0357 | Push Notifications | `push-notifications.ts` |
| XEP-0333 | Chat Markers | `MessagingContext.tsx`, `ChatPage.tsx`, `MessageItem.tsx` |
| XEP-0030 | Service Discovery | `xmpp.ts`, `push-notifications.ts` |
| XEP-0077 | In-Band Registration | `xmpp.ts` |
| XEP-0199 | XMPP Ping | Stanza.js built-in |

### 2. **IndexedDB (Local)**

**Database**: `alfred-xmpp-db`
**Stores**:
- `conversations` - Lista conversazioni
- `messages` - Tutti i messaggi (con Observer pattern per real-time)
- `vcards` - Avatar e profili contatti
- `metadata` - **Marker sync** (lastRSMToken, isInitialSyncComplete)

**Gestione**: Tramite `repositories/` layer (Observer pattern su MessageRepository)

### 3. **Service Worker**

**Scope**: `/XmppTest/`
**File**: `public/sw.js`
**Funzionalità**:
- Cache asset statici per offline
- Push notifications receiver
- Background sync (future)

### 4. **Browser APIs Utilizzate**

- **Notification API** - Push notifications
- **Service Worker API** - Offline support
- **IndexedDB API** - Data persistence
- **WebSocket API** - XMPP connection

---

## 🔧 Build e Testing

### Script NPM Disponibili

```bash
# Development
npm run dev              # Start Vite dev server (hot reload)
npm run build            # Build production (TypeScript check + Vite build)
npm run preview          # Preview production build

# Quality
npm run lint             # Run ESLint
npm run type-check       # TypeScript type checking (implicito in build)

# Testing
npm run test:browser     # Run Playwright browser tests
npm run test:browser:setup  # Install Playwright browsers
```

### Build Configuration

**Tool**: Vite 7.2.4  
**Config File**: `vite.config.ts`

**Ottimizzazioni Build**:
- Code splitting automatico per vendor libraries:
  - `react-vendor` - React, React DOM, React Router
  - `xmpp-vendor` - Stanza.js
  - `db-vendor` - idb
  - `pages` - ChatPage, ConversationsPage
  - `services` - xmpp, messages, conversations, sync-initializer

**Base URL**: `/XmppTest/` (per GitHub Pages)

**Output**: `/workspace/web-client/dist/`

### TypeScript Configuration

**Strict Mode**: Abilitato  
**Config Files**:
- `tsconfig.json` - Base config
- `tsconfig.app.json` - App source
- `tsconfig.node.json` - Vite config

**Target**: ES2020  
**Module**: ESNext

### Linting

**Tool**: ESLint 9.39.1  
**Config**: `eslint.config.js`  
**Plugins**:
- `react-hooks` - React hooks rules
- `react-refresh` - Fast refresh

### Testing

**Framework**: Playwright 1.57.0  
**Test Files**: `web-client/test-*.mjs` (7 file di test)

**Test Scenarios**:
- Browser integration tests
- vCard photo upload/download
- Push notifications
- Login flow

**Nota**: Unit tests non ancora implementati (future)

### Deployment

**Target**: GitHub Pages  
**Workflow**: `.github/workflows/deploy-pages.yml`  
**Trigger**: Push su branch `main`  
**URL**: Configurabile tramite `vite.config.ts` base URL

---

## 💾 Database e Storage

### IndexedDB Structure

**Database Name**: `alfred-xmpp-db`  
**Version**: Gestita da `idb` (auto-upgrade)

#### Object Stores

##### 1. **conversations**
```typescript
{
  id: string              // JID della conversazione
  jid: string             // JID XMPP completo
  name?: string           // Nome dal roster o vCard
  lastMessage?: string    // Preview ultimo messaggio
  lastMessageTime?: number // Timestamp ultimo messaggio
  unreadCount?: number    // Conteggio messaggi non letti
  avatar?: string         // Avatar URL o base64
  presence?: string       // Stato presenza (available, away, etc.)
}
```
**Indexes**: `jid` (unique)

##### 2. **messages**
```typescript
{
  messageId: string       // ID dal server o generato locale
  conversationJid: string // JID bare del contatto (FK)
  body: string            // Testo messaggio (vuoto per marker)
  timestamp: Date         // Timestamp messaggio
  from: 'me' | 'them'     // Direzione
  status: 'pending' | 'sent' | 'delivered' | 'failed'
  tempId?: string         // ID temporaneo pre-conferma
  
  // XEP-0333 Chat Markers
  markerType?: 'received' | 'displayed' | 'acknowledged'
  markerFor?: string      // messageId del messaggio referenziato
}
```
**Note strategia**:
- Messaggi testuali: `body !== ''`, `markerType === undefined`
- Marker: `body === ''`, `markerType !== undefined`, `markerFor` punta al messaggio
- Marker salvati come messaggi separati, applicati visivamente nel rendering

**Indexes**: 
- `conversationJid` (non-unique) - Per query per conversazione
- `timestamp` (non-unique) - Per sorting temporale
- `conversation-timestamp` (compound) - Query efficienti
- `tempId` (non-unique) - Lookup messaggi temporanei

##### 3. **vcards**
```typescript
{
  jid: string             // JID utente (primary key)
  fullName?: string       // Nome completo
  nickname?: string       // Nickname
  email?: string          // Email
  photoType?: string      // MIME type avatar (es. image/jpeg)
  photoData?: string      // Base64 encoded photo
  lastUpdated: number     // Timestamp ultimo aggiornamento
}
```
**Indexes**: `jid` (unique)

##### 4. **metadata**
```typescript
{
  key: string             // Chiave metadato
  value: any              // Valore (JSON serializzabile)
}
```
**Keys utilizzate** (Architettura "Sync-Once + Listen"):
- `lastSync` - Timestamp ultima sync
- `lastRSMToken` - Token RSM (XEP-0059) per sync incrementale
- `isInitialSyncComplete` - Flag se sync iniziale completata
- `initialSyncCompletedAt` - Timestamp completamento sync iniziale

### LocalStorage

**Keys utilizzate** (da `constants.ts`):

| Key | Tipo | Uso |
|-----|------|-----|
| `xmpp_jid` | string | JID utente per auto-login |
| `xmpp_password` | string | Password (⚠️ encrypted future) |
| `push_config` | JSON | Configurazione push notifications |

⚠️ **Security Note**: Le password sono attualmente in plain text nel localStorage. Encryption pianificata per versioni future.

### Repository Pattern

Tutti gli accessi al database avvengono tramite Repository:

```typescript
// Esempio: ConversationRepository
class ConversationRepository {
  async getAll(): Promise<Conversation[]>
  async getById(jid: string): Promise<Conversation | undefined>
  async save(conversation: Conversation): Promise<void>
  async delete(jid: string): Promise<void>
  async search(query: string): Promise<Conversation[]>
}
```

**ARCHITETTURA "SYNC-ONCE + LISTEN"**:
- `MessageRepository` implementa **Observer Pattern** per real-time updates
- `MetadataRepository` gestisce marker per sync incrementale

**Vantaggi**:
- Separation of concerns
- Facilita testing
- Centralizza logica database
- Real-time updates senza polling

---

## 📊 Stato Corrente

### ✅ Funzionalità Implementate

**Architettura v3.0 "Sync-Once + Listen" (15 dicembre 2025)**:
- ✅ **Sync iniziale** (full o incremental) all'avvio
- ✅ **Sync status indicator** nella ConversationsPage
- ✅ **Real-time messaging** tramite Observer pattern
- ✅ **Clear DB** tool nel Debug Logger

**Core Features**:
- ✅ **Login XMPP** con popup glassmorphism
- ✅ **Auto-login** da localStorage
- ✅ **Lista conversazioni** con ricerca (cache-only)
- ✅ **Chat 1-to-1** con invio/ricezione real-time
- ✅ **vCard** (avatar, profilo utente)
- ✅ **MAM (Message Archive Management)** per storico messaggi (solo all'avvio)
- ✅ **Paginazione messaggi** (load more da cache)
- ✅ **Cache-first loading** (IndexedDB)
- ✅ **Offline support** (Service Worker)
- ✅ **Push Notifications** (XEP-0357) con abilitazione automatica
- ✅ **Chat Markers (XEP-0333)** - Spunte di lettura stile WhatsApp/Telegram
  - Marker sincronizzati da MAM come messaggi speciali
  - Applicazione visiva durante rendering (no modifica DB)
  - ✓ grigia (sent), ✓✓ grigie (displayed), ✓✓ blu (acknowledged)
- ✅ **Typing indicators** (future - base implementata)
- ✅ **Presence** (online/offline status)
- ✅ **Debug Logger** (intercetta e visualizza tutti i console.log)

### 🚧 In Development / Roadmap

- 🚧 **Chat di gruppo (MUC)** - XEP-0045
- 🚧 **OMEMO (E2E Encryption)** - XEP-0384
- 🚧 **File upload** - XEP-0363
- 🚧 **Voice/Video calls** - Jingle (XEP-0166)
- 🚧 **Dark mode**
- 🚧 **Emoji picker**
- 🚧 **Markdown support**
- 🚧 **Message reactions**
- 🚧 **Message deletion** (locale - non server)
- 🚧 **PWA install prompt**

### ⚠️ Known Issues

Documentati in `docs/fixes/known-issues.md`:

1. **Push Notifications**: Richiede configurazione server XMPP con servizio push
2. **Password Storage**: Plain text in localStorage (encryption planned)
3. ~~**MAM Performance**: Sync iniziale può essere lenta con molti messaggi~~ ✅ RISOLTO v3.0 (sync incremental)
4. **Profile Photo**: Alcuni server XMPP non supportano vCard photo

### 🔍 Testing Status

| Area | Copertura | Note |
|------|-----------|------|
| **E2E Tests** | ⚠️ Parziale | Playwright tests esistenti ma non completi |
| **Unit Tests** | ❌ Nessuna | Pianificati per Q1 2026 |
| **Integration Tests** | ❌ Nessuna | Pianificati per Q1 2026 |
| **Manual Testing** | ✅ Completo | Testing manuale su feature implementate |

### 📈 Performance Metrics

**Target Performance** (da README.md):
- ⚡ Apertura chat: < 100ms (cache hit)
- ⚡ Lista conversazioni: < 200ms (cache hit)
- ⚡ Invio messaggio: < 500ms (network)

**Ottimizzazioni Implementate** (Architettura v3.0):
1. **Sync-Once + Listen**: 1 sync all'avvio, poi 0 query server durante utilizzo (~95% riduzione query)
2. **Cache-first loading** (IndexedDB): < 100ms apertura chat
3. **Observer pattern**: Real-time updates senza polling
4. **Code splitting** per vendor libraries
5. **Lazy loading** messaggi con pagination (da cache)
6. **Debounced search** input
7. **Eliminato pull-to-refresh**: -100% overhead inutile
8. Virtualized list (future)

### 🔒 Security Status

**Implementato**:
- ✅ WebSocket TLS (wss://)
- ✅ XMPP SASL authentication
- ✅ XEP-0077 In-Band Registration

**Da Implementare**:
- ❌ Password encryption in localStorage
- ❌ OMEMO (E2E encryption)
- ❌ CSP (Content Security Policy) headers
- ❌ Rate limiting client-side

### 📱 Browser Compatibility

**Supportato**:
- ✅ Chrome/Edge 90+ (desktop + mobile)
- ✅ Firefox 88+ (desktop + mobile)
- ✅ Safari 14+ (desktop + mobile)

**Richiede**:
- Service Worker support
- IndexedDB support
- WebSocket support
- ES2020 support

### 🎨 Design System

**Nome Ufficiale**: Alfred - Messaggistica istantanea

**Colore Istituzionale**: `#2D2926` (Dark Charcoal)
- Hover: `#3d3632`
- Active: `#1e1b19`
- Gradient: `linear-gradient(135deg, #2D2926, #4a433e)`
- Contrasto: 15.8:1 con bianco (WCAG AAA)

**Logo**: Spunta (✓) in cerchio - SVG in `SplashScreen.tsx`

**Typography**: 
- Font Family: 'Inter', 'SF Pro Display', system-ui
- Heading: 24px/700, 20px/600, 18px/600
- Body: 14px/400, Small: 12px/400

**UI Pattern**: Ispirato a Telegram/WhatsApp web
- Layout: Sidebar + Main panel
- Componenti: Glassmorphism per modal
- Animazioni: 150-300ms ease-in-out

**CSS Files con colore**: index.css, ConversationsPage.css, ChatPage.css, NewConversationPopup.css, LoginPopup.css

---

## 🔄 Ultima Revisione

**Data**: 2025-12-17  
**Branch**: `cursor/message-read-receipts-support-46f8`  
**Versione**: Architettura v3.0 "Sync-Once + Listen" + XEP-0333 Chat Markers

**Modifiche Recenti** (v3.1 - 17 dicembre 2025):
- ✅ **Implementato XEP-0333 (Chat Markers)** - Spunte di lettura stile WhatsApp/Telegram:
  - Schema Message esteso con `markerType` e `markerFor`
  - Marker sincronizzati da MAM come messaggi speciali (body vuoto, hanno markerType + markerFor)
  - Marker salvati nel DB locale esattamente come arrivano dal server (no modifica)
  - Strategia rendering: ciclo messaggi → se testo mostra, se marker cerca referenziato e applica spunta
  - Invio marker real-time: client.markDisplayed quando si visualizzano messaggi
  - UI con spunte: ✓ (sent), ✓✓ grigie (displayed), ✓✓ blu (acknowledged)
  - CSS stile WhatsApp con `letter-spacing: -4px` per sovrapporre le spunte
  - Logica applicazione marker interamente nel rendering (MessageItem), no modifica DB

**Modifiche Precedenti** (v3.0.1 - 17 dicembre 2025):
- ✅ **Ripristinato auto-login funzionante**:
  - ConnectionContext ora gestisce auto-login all'avvio con useEffect
  - Credenziali migrate da sessionStorage a localStorage per persistenza
  - LoginPopup riceve prop isInitializing per mostrare spinner durante auto-login
  - Documenti: XmppContext deprecato (sostituito da ConnectionContext)
- ✅ **Fix architetturale**:
  - Logica auto-login persa durante refactoring context ora ripristinata
  - auth-storage.ts ora usa localStorage invece di sessionStorage

**Modifiche Precedenti** (v3.0 - 15 dicembre 2025):
- ✅ **Implementata architettura "Sync-Once + Listen"**:
  - Sync SOLO all'avvio (full se DB vuoto, incremental se popolato)
  - Real-time messaging tramite Observer pattern
  - Eliminato pull-to-refresh (-100% overhead)
  - Riduzione 93% punti di sincronizzazione (da 15+ a 1)
  - Riduzione 70% codice sync (da ~1700 a ~530 righe)
  - Riduzione 95% query server durante utilizzo
- ✅ **Nuovi componenti**:
  - `AppInitializer.tsx` - Wrapper per sync startup
  - `sync-initializer.ts` - Orchestrazione sync (full/incremental)
  - `sync-status.ts` - Observable sync status per UI
- ✅ **Rimossi componenti obsoleti** (eliminati dal codebase):
  - `usePullToRefresh.ts`
  - `sync.ts`
  - `SyncService.ts`
  - `src/repositories/` (duplicato non usato)
  - `App.css` (landing page legacy)
- ✅ **UI improvements**:
  - Loading spinner in ConversationsPage durante sync
  - "Clear DB" button in DebugLogPopup
- ✅ **Documentazione aggiornata**:
  - PROJECT_MAP.md (questo file)
  - docs/implementation/sync-system-complete.md (completamente riscritto)
  - docs/architecture/README.md
  - README.md principale

---

## 📞 Contatti e Risorse

- **Repository**: GitHub (URL da configurare)
- **Documentazione Completa**: `/workspace/docs/`
- **Issues**: GitHub Issues
- **License**: MIT (vedi `/workspace/LICENSE`)

---

**Nota**: Questo documento è generato e mantenuto come "punto di verità" per il progetto Alfred. Deve essere aggiornato ad ogni cambio significativo di architettura, dipendenze, o responsabilità.
