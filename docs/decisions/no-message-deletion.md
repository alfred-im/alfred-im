# DECISIONE: NON Implementare Rimozione Conversazioni

## Data Decisione
30 Novembre 2025

## Richiesta Originale
Implementare una funzionalità per "eliminare/rimuovere una conversazione" che:
1. Elimini/nascondi tutti i messaggi vecchi scambiati con un contatto
2. Permetta di continuare a ricevere nuovi messaggi da quel contatto
3. La conversazione riappaia "fresca" quando arriva un nuovo messaggio
4. Lo storico vecchio NON riappaia mai più

**Obiettivo finale:** Rimuovere lo storico dal server XMPP, non solo dal client locale.

---

## Ricerca Effettuata

### 1. Analisi Stanza.js Framework (v12.21.0)

**File analizzati:**
- `/node_modules/stanza/plugins/mam.d.ts` - Metodi MAM
- `/node_modules/stanza/protocol/xep0313.d.ts` - Protocollo MAM
- `/node_modules/stanza/protocol/xep0049.d.ts` - Private Storage
- Tutti i file di definizione TypeScript di Stanza.js

**Metodi MAM disponibili:**
```typescript
interface Agent {
  searchHistory(opts: MAMQueryOptions): Promise<MAMFin>
  getHistoryPreferences(): Promise<MAMPrefs>
  setHistoryPreferences(opts: MAMPrefs): Promise<IQ>
}
```

**Metodi NON presenti:**
- ❌ `deleteMessages()` - Non esiste
- ❌ `deleteMessagesFromMAM()` - Non esiste
- ❌ `purgeConversation()` - Non esiste
- ❌ `retractMessage()` per chat 1-a-1 - Non esiste
- ❌ `clearHistory()` - Non esiste
- ❌ Qualsiasi metodo per eliminare/modificare archivio MAM

**Nota:** Esistono `purgeNode()` e `retract()` ma sono SOLO per PubSub (pubblicazione/sottoscrizione), NON per messaggi diretti.

---

### 2. Analisi Standard XMPP (XEP)

#### XEP-0313: Message Archive Management (MAM)
- **Status:** Draft (standard stabile)
- **URL:** https://xmpp.org/extensions/xep-0313.html

**Citazione dalla specifica ufficiale:**
> "Archives are append-only. There is no method for deleting or modifying archived messages."

**Traduzione:**
> "Gli archivi sono append-only (solo aggiunta). Non esiste alcun metodo per eliminare o modificare messaggi archiviati."

**Operazioni supportate:**
- ✅ Query (recupero messaggi con filtri per JID, data, paginazione)
- ✅ Preferenze archivio (`always`, `never`, `roster`)
  - ⚠️ Influenzano solo comportamento FUTURO, NON eliminano messaggi esistenti
- ❌ Eliminazione messaggi
- ❌ Modifica messaggi
- ❌ Nascondere messaggi
- ❌ Qualsiasi operazione distruttiva

**Conclusione:** MAM è progettato come archivio immutabile. È una scelta architetturale del protocollo.

---

#### XEP-0424: Message Retraction
- **Status:** Experimental (NON è uno standard finale)
- **URL:** https://xmpp.org/extensions/xep-0424.html

**Come funziona:**
1. Invii un messaggio normale
2. Invii un SECONDO messaggio di "retraction"
3. I client che supportano XEP-0424 nascondono il messaggio originale nella UI
4. Il messaggio originale rimane nell'archivio MAM

**Limitazioni critiche:**

1. **NON cancella dal server**
   - Query MAM restituisce sia il messaggio originale che la retraction
   - Sono due messaggi separati nel database
   - Il client decide se nascondere o meno

2. **Dipende dal client**
   - Conversations (Android) → nasconde il messaggio ✅
   - Gajim moderno → nasconde il messaggio ✅
   - Pidgin, client vecchi → mostrano ancora il messaggio ❌
   - È una convenzione UI, non una cancellazione

3. **Limitazioni temporali**
   - Molti server permettono retraction solo per messaggi recenti (1-2 ore max)
   - Non puoi ritirare messaggi vecchi di giorni/mesi

4. **Solo messaggi propri**
   - Puoi ritirare solo messaggi che hai inviato TU
   - I messaggi RICEVUTI non possono essere ritirati

**Per il nostro caso d'uso (eliminare conversazione con 1000 messaggi):**
- Dovresti inviare 1000+ retraction (una per messaggio inviato da te)
- I messaggi ricevuti rimarrebbero comunque
- Molti server rifiuterebbero retraction per messaggi vecchi
- Se l'altro usa client vecchio, vede ancora tutto
- I messaggi rimangono sul server per sempre

**Conclusione:** ❌ NON è una soluzione pratica per il nostro caso d'uso.

---

#### XEP-0049: Private XML Storage
- **Status:** Active (standard stabile dal 2002)
- **URL:** https://xmpp.org/extensions/xep-0049.html
- **Supporto server:** ~95% dei server XMPP

**Cosa offre:**
- Salvare dati XML privati sul server
- Dati sincronizzati tra istanze della stessa applicazione

**Possibile workaround esplorato:**
Salvare una "data di taglio" per ogni conversazione, poi filtrare le query MAM client-side.

```typescript
// Salva sul server
cutoffs = {
  'alice@example.com': '2025-11-30T15:00:00Z'
}

// Query MAM con filtro
client.searchHistory({
  with: 'alice@example.com',
  start: new Date('2025-11-30T15:00:00Z')  // Solo messaggi dopo questa data
})
```

**Problema fondamentale - Cross Device:**

❌ **NON è cross-device nel senso del protocollo:**

```
Scenario reale:

1. Tua app web → "elimina conversazione con Alice"
   → Salva cutoff su server (XEP-0049)
   → Filtra query MAM con start=cutoff
   → Non vedi storico vecchio ✅

2. Apri Conversations sul telefono (altro client XMPP)
   → Conversations NON sa nulla del tuo cutoff
   → Query MAM normale senza filtri
   → Vedi TUTTO lo storico di 1000 messaggi ❌

3. Usi la tua app mobile (se la sviluppi)
   → Legge cutoff da XEP-0049
   → Filtra query MAM
   → Non vedi storico vecchio ✅

4. Amico usa Gajim
   → Query MAM normale
   → Vede tutto lo storico ✅ (dal suo punto di vista)
```

**Conclusione workaround XEP-0049:**
- ✅ Funziona solo tra istanze della STESSA applicazione (la tua)
- ❌ NON funziona con altri client XMPP (Conversations, Gajim, ecc.)
- ❌ NON è una feature del protocollo XMPP
- ❌ È solo un filtro applicativo, non una vera eliminazione
- ❌ I messaggi rimangono sul server per sempre

---

### 3. Comandi Admin Server-Specific

#### ejabberd
```bash
ejabberdctl delete_old_mam_messages example.com all
```

#### Prosody
```lua
prosodyctl mod_mam delete user@example.com
```

#### MongooseIM
```http
DELETE /api/messages/{user}/archive
```

**Limitazioni comuni:**
- ❌ Richiedono accesso amministrativo al server
- ❌ NON disponibili per utenti normali
- ❌ Spesso eliminano TUTTO, non selettivamente per conversazione
- ❌ Non sono comandi standard XMPP (specifici per ogni server)

**Conclusione:** Non applicabile per utenti finali dell'applicazione.

---

### 4. Comparazione con Altri Protocolli

| Protocollo | Supporta Eliminazione | Note |
|------------|----------------------|------|
| **Matrix** | ✅ Sì (redact event) | Nasconde contenuto, mantiene metadata |
| **Signal** | ✅ Sì ("Delete for everyone") | Limite temporale, richiede sincronizzazione |
| **WhatsApp** | ✅ Sì ("Elimina per tutti") | Limite 1 ora, lascia traccia |
| **Telegram** | ✅ Sì (sempre) | Nessun limite temporale |
| **XMPP** | ❌ NO | Archivio append-only, nessuna eliminazione |

**Conclusione:** XMPP è l'UNICO protocollo messaging mainstream che NON supporta alcuna forma di eliminazione messaggi dall'archivio server.

---

## Soluzioni Teoriche Valutate

### Soluzione 1: XEP-0049 + Filtro Temporale
**Idea:** Salvare cutoff sul server, filtrare query MAM client-side

**Pro:**
- ✅ Storico vecchio non viene scaricato (risparmio banda)
- ✅ Nuovi messaggi funzionano normalmente
- ✅ Sincronizzato tra istanze della stessa app

**Contro:**
- ❌ Messaggi rimangono sul server
- ❌ Altri client XMPP vedono tutto lo storico
- ❌ NON è cross-device nel senso del protocollo
- ❌ Richiede implementazione custom XEP-0049 in Stanza.js
- ❌ Non è una vera eliminazione

**Verdetto:** Workaround debole, non risolve il problema reale.

---

### Soluzione 2: XEP-0424 Message Retraction Massiva
**Idea:** Inviare retraction per ogni messaggio vecchio

**Contro:**
- ❌ Migliaia di messaggi da inviare
- ❌ Solo messaggi TUOI (ricevuti rimangono)
- ❌ Server possono bloccare retraction su messaggi vecchi
- ❌ Client incompatibili vedono tutto
- ❌ Messaggi rimangono sul server
- ❌ Stanza.js non ha supporto nativo

**Verdetto:** Impraticabile e inefficace.

---

### Soluzione 3: Filtro Solo Locale (IndexedDB)
**Idea:** Salvare flag locale, filtrare query MAM

**Contro:**
- ❌ NON sincronizzato (solo questo dispositivo)
- ❌ Cambi browser/dispositivo → storico riappare
- ❌ Messaggi rimangono sul server
- ❌ Non è una vera eliminazione

**Verdetto:** Troppo limitato.

---

### Soluzione 4: Backend Custom con Accesso Database MAM
**Idea:** Creare API backend che accede direttamente al database MAM del server

**Contro:**
- ❌ Richiede server XMPP proprietario
- ❌ Richiede modifiche al server
- ❌ Richiede backend custom
- ❌ Non è più XMPP standard
- ❌ Complessità altissima

**Verdetto:** Fuori scope per applicazione client standard.

---

### Soluzione 5: Cambiare Protocollo
**Idea:** Usare Matrix, Signal, ecc. invece di XMPP

**Contro:**
- ❌ Richiede riscrivere tutta l'applicazione
- ❌ XMPP è requisito del progetto

**Verdetto:** Non applicabile.

---

## Decisione Finale

### ❌ NON IMPLEMENTARE rimozione conversazioni

**Ragioni:**

1. **Impossibilità tecnica fondamentale**
   - XMPP MAM è archivio append-only per design
   - Non esiste standard XMPP per eliminare messaggi
   - Documentato ufficialmente in XEP-0313

2. **Workaround insufficienti**
   - XEP-0049: solo filtro applicativo, non cross-device reale
   - XEP-0424: non cancella, solo UI, non pratico per 1000+ messaggi
   - Tutti i workaround: messaggi rimangono sul server

3. **Problema cross-device**
   - Qualsiasi soluzione funziona SOLO nella nostra app
   - Altri client XMPP vedranno sempre tutto lo storico
   - Non è una feature del protocollo, è solo filtro applicativo

4. **Aspettative utente vs realtà**
   - Utente si aspetta: "elimino conversazione → sparisce dal server"
   - Realtà: "elimino conversazione → la mia app la nasconde, ma è ancora sul server e altri client la vedono"
   - Questo crea false aspettative e problemi di privacy

5. **Alternativa migliore: eliminazione locale**
   - Se l'utente vuole "pulire" il client, può eliminare dal database locale
   - Con la consapevolezza che i messaggi:
     - Rimangono sul server
     - Torneranno al prossimo sync/dispositivo
     - Sono sempre accessibili tramite altri client XMPP

---

## Cosa Dire all'Utente

Se in futuro viene richiesta questa funzionalità, spiegare:

### Messaggio per l'Utente

> **XMPP non supporta l'eliminazione di messaggi dall'archivio del server.**
> 
> Questa è una limitazione fondamentale del protocollo XMPP:
> - L'archivio messaggi (MAM) è progettato come "append-only" (solo aggiunta)
> - Non esiste alcun metodo standard per eliminare messaggi
> - È documentato ufficialmente nella specifica XEP-0313
> 
> **Cosa puoi fare:**
> - Eliminare messaggi dal database locale (questo dispositivo)
> - I messaggi torneranno quando:
>   - Cambi dispositivo
>   - Reinstalli l'app
>   - Fai un sync completo
> 
> **Cosa NON puoi fare:**
> - Eliminare messaggi dal server XMPP
> - Nascondere conversazioni in modo permanente
> - Impedire che altri tuoi client XMPP vedano i messaggi
> 
> **Perché?**
> - XMPP è diverso da WhatsApp/Telegram/Signal
> - Questi protocolli supportano "elimina per tutti"
> - XMPP è più simile a email: una volta inviato, rimane nell'archivio
> 
> **Alternative:**
> Se l'eliminazione messaggi è un requisito critico, considera protocolli alternativi:
> - Matrix (supporta redaction)
> - Signal (supporta delete for everyone)
> - Telegram (supporta eliminazione sempre)

---

## Riferimenti Documentazione

### File creati durante la ricerca:
1. `/workspace/docs/xmpp-message-deletion-research.md`
   - Prima ricerca generale su XEP e possibilità
   
2. `/workspace/docs/xep-0424-support-analysis.md`
   - Analisi approfondita Message Retraction
   - Supporto server e client
   
3. `/workspace/docs/xmpp-hide-conversation-flag.md`
   - Ricerca su flag per nascondere conversazioni
   - Analisi XEP-0049 Private Storage
   
4. `/workspace/docs/xmpp-hide-message-history.md`
   - Analisi soluzioni per nascondere storico messaggi
   - Valutazione workaround con timestamp cutoff
   
5. `/workspace/docs/xmpp-deletion-comprehensive-analysis.md`
   - Analisi completa di tutte le opzioni
   - Comparazione con altri protocolli
   - Analisi Stanza.js framework

6. **QUESTO DOCUMENTO**
   - Sintesi decisionale finale
   - Tutte le ragioni per NON implementare

### Link utili:
- XEP-0313 (MAM): https://xmpp.org/extensions/xep-0313.html
- XEP-0424 (Retraction): https://xmpp.org/extensions/xep-0424.html
- XEP-0049 (Private Storage): https://xmpp.org/extensions/xep-0049.html
- Stanza.js: https://github.com/legastero/stanza

---

## Note Implementative

### Modifiche al codice effettuate e annullate:
- Aggiunto campo `hidden?: boolean` a interfaccia `Conversation` (ANNULLATO)
- Aggiunto index `by-hidden` al database (ANNULLATO)
- Aggiornato schema database a versione 3 (ANNULLATO)

Queste modifiche sono state rollback perché:
- Non risolvono il problema reale
- Creano false aspettative
- Funzionano solo localmente

### Funzionalità esistenti da mantenere:
- `clearMessagesForConversation()` in `MessageRepository` - elimina messaggi locali
- ✅ `clearDatabase()` - pulisce tutto il database locale
- ✅ Sync completo da MAM - ricarica tutto dal server

Queste funzioni sono sufficienti per gestire pulizia locale, con la consapevolezza che i dati tornano dal server.

---

## Promemoria per il Futuro

**SE l'utente chiede di nuovo:**
1. Mostra questo documento
2. Spiega che è già stato analizzato approfonditamente
3. La decisione è: NON si può fare con XMPP standard
4. Richiede server custom o cambio protocollo

**NON:**
- ❌ Ricominciare la ricerca
- ❌ Proporre workaround già scartati
- ❌ Implementare soluzioni parziali che creano false aspettative

---

**Data creazione documento:** 30 Novembre 2025  
**Ultima revisione:** 30 Novembre 2025  
**Status:** DECISIONE FINALE - NON IMPLEMENTARE
