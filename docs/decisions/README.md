# Decisioni Architetturali (ADR)

Architecture Decision Records per tracciare decisioni importanti e motivazioni. Documento per AI.

## Decisioni Documentate

### 1. No Message Deletion
- **[no-message-deletion.md](./no-message-deletion.md)**
- **Data**: Novembre 2025
- **Status**: ✅ Accettata
- **Summary**: Non implementare cancellazione messaggi XMPP

**Perché**: 
- XEP-0424 non supportato da conversations.im
- Complessità implementativa alta
- Benefici limitati per utenti finali
- Alternative esistenti (hide conversation)

### 2. No Modify Source Data
- **[no-modify-source-data.md](./no-modify-source-data.md)**
- **Data**: Dicembre 2025
- **Status**: Regola maestra
- **Summary**: Non modificare/eliminare dati in IndexedDB come scorciatoia; filtrare in lettura/rendering

### 3. MAM Global Strategy
- **Status**: ✅ Accettata  
- **Summary**: Usare query MAM globale invece di N query per contatto

**Perché**:
- Una query vs N query (efficienza)
- Cache completa locale
- Apertura chat istantanea
- Funzionamento offline

Dettagli: [../architecture/mam-global-strategy-explained.md](../architecture/mam-global-strategy-explained.md)

### 4. HashRouter vs BrowserRouter
- **Status**: ✅ Accettata
- **Summary**: Usare HashRouter per GitHub Pages compatibility

**Perché**:
- GitHub Pages è hosting statico (no server-side routing)
- BrowserRouter richiede configurazione server per SPA
- HashRouter funziona out-of-the-box
- Nessun 404 su refresh

Dettagli: `PROJECT_MAP.md` (HashRouter in App.tsx), `README.md`

### 5. IndexedDB per Cache
- **Status**: ✅ Accettata  
- **Summary**: Usare IndexedDB invece di localStorage

**Perché**:
- Quota: 50MB+ vs 5-10MB
- Performance: Async vs sync blocking
- Tipi: Supporta binary (avatar) direttamente
- Scalabilità: Gestisce migliaia di messaggi

### 6. IndexedDB per account (v2.2)
- **Status**: ✅ Accettata (17 giugno 2026)
- **Summary**: Un database IndexedDB per JID utente (`conversations-db-{account}`)

**Perché**:
- Cambio account senza mescolare conversazioni/messaggi/token sync
- Storico locale conservato al logout (nessun wipe)
- Migrazione automatica dal DB legacy condiviso `conversations-db`
- Alternativa scartata: wipe al logout (inaccettabile con storico lungo)
- Alternativa futura possibile: `ownerJid` nello schema su DB unico

Dettagli: [../fixes/account-storage-isolation.md](../fixes/account-storage-isolation.md), `PROJECT_MAP.md` sezione Database

### 7. Stanza.js vs Alternative
- **Status**: ✅ Accettata
- **Summary**: Usare Stanza.js per XMPP

**Perché**:
- Manutenzione attiva
- Browser-focused (WebSocket/BOSH)
- TypeScript support
- Plugin ecosystem
- Documentazione completa

### 8. Bridge stateless (2026-06-24)
- **[bridge-stateless.md](./bridge-stateless.md)**
- **Status**: ✅ Accettata — regola vincolante
- **Summary**: I bridge XMPP/Matrix non tengono stato di business; tutto su Supabase

**Perché**:
- Scale-out con load balancer + N repliche
- Crash/restart senza perdita dati
- Coerente con “piattaforma = fonte di verità” e principio card
- Evita sync token e cursori solo in RAM

### 9. Ricezione = ricezione sul server (2026-06-26)
- **[server-as-reception.md](./server-as-reception.md)**
- **Status**: ✅ Accettata — **concept vincolante** dell'applicazione
- **Summary**: Client cloud multidispositivo; la ricezione coincide con la ricezione sul server (fonte di verità). Oggi invio/ricezione sembrano sincroni; col tempo saranno disaccoppiati come tra server diversi (federazione).

**Perché**:
- Coerente con Supabase come fonte di verità e accesso da più device
- Spunta ✓✓ grigia = consegnato al server, non al singolo device del destinatario
- Prepara il modello spunte per bridge/outbox senza cambiare semantica UI
- Distingue il client Flutter Alpha dal legacy XMPP (XEP-0184 = device)

### 10. Nessuna distinzione chat interna / esterna (2026-06-27)
- **[no-internal-external-chat-distinction.md](./no-internal-external-chat-distinction.md)**
- **Status**: ✅ Accettata — **regola vincolante**
- **Summary**: La distinzione chat interna/esterna non esiste e non deve esistere a **nessun livello** (UI, client, piattaforma Supabase, bridge, test, documentazione). Una sola chat end-to-end; `protocol` solo percorso di recapito uscente.

**Perché**:
- Coerente con protocollo invisibile in UI (discovery)
- Evita doppie implementazioni (scroll, aggancio al fondo, composer, ecc.)
- L'utente vede chat, non tipi di chat

**Implementazione aggancio**: [conversation-bottom-anchor.md](../design/conversation-bottom-anchor.md) — PR #125

## Decisioni In Valutazione

- **Virtual Scrolling**: Liste > 100 elementi (react-window vs react-virtualized)
- **PWA**: Service Worker completo + install prompt
- **OMEMO**: XEP-0384 (complessità vs benefici in ricerca)
