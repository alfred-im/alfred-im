# Proposta — modello caselle (direzione)

**Ultima revisione**: 2026-06-28  
**Status**: 🟡 **Direzione confermata** — da implementare su dev; **non** ancora su `main`  
**Audience**: AI / implementazione

**Su `main` oggi** vale ancora [address-based-messaging.md](../decisions/address-based-messaging.md). Questo file descrive il **target** concordato; all’implementazione **sostituisce** quell’ADR.

---

## Delta rispetto a oggi

| | Oggi (`main`) | Target caselle |
|--|---------------|----------------|
| **Archivio** | 1 riga `messages` condivisa tra i due peer | Un archivio per owner: io ho i miei messaggi in/out, tu i tuoi |
| **Consegna** | Internal: insert diretto + `delivered`; federato: outbox | **Outbox sempre** (anche internal), poi materializzazione nell’archivio del destinatario — un solo tipo di pipeline |
| **Inbox** | Query live su `messages` (`list_inbox()`) | Lista derivata dal **mio** archivio |
| **Identità chat** | `(io, peer_profile_id)` | `(io, indirizzo peer)` — `username` o `username@server` |

Tutto il resto (UI, realtime, spunte, tipi messaggio, rubrica) si deduce dall’Alpha attuale salvo quanto sotto.

---

## Media (GIF, voice) — file condiviso

Il flusso client resta quello Alpha: **un upload** nel bucket `chat-media` → **un** `media_url` → metadati sul messaggio.

Con il modello caselle le **copie d’archivio** (mittente e destinatario) puntano allo **stesso blob** — il file **non** si duplica in storage. È una scelta deliberata (come un allegato referenziato in due caselle), non un dettaglio trascurabile.

### Implicazioni

| Aspetto | Conseguenza |
|---------|-------------|
| **Riferimento** | Più righe `mailbox_messages` possono condividere lo stesso `media_url` |
| **Garbage collection** | Eliminare un messaggio o una casella **non** implica che il file sia orfano: va verificato se **altre** copie (o altri owner) referenziano ancora quell’URL prima di cancellare da `chat-media` |
| **Delete locale** (futuro) | Cancello la chat dal mio lato → la mia riga sparisce, ma il peer può ancora referenziare lo stesso file |
| **Rimozione lato mittente** | Cancellare il file in storage mentre il destinatario ha ancora il messaggio → **link rotto** per il peer, salvo policy esplicita |
| **Retry / invio fallito** | Upload riuscito ma consegna non materializzata → blob in storage senza (o con) riga archivio — edge case da contare nel GC |
| **Bridge** (futuro) | Il bridge può aver scaricato/cachato dal URL; delete storage non equivale a «revocato» fuori da Alfred |

**Regola:** trattare i media come **risorsa condivisa con refcount logico** (o audit delle referenze), non come proprietà della singola riga archivio. La strategia GC (quando contare le referenze, job async, soft-delete) va definita **prima** di implementare delete messaggi/casella o purge storage — fuori scope Alpha ma **non** ignorabile nel design.

---

## Identità chat (vincolante)

**Non serve altro** oltre a:

1. **Il mio account** (`auth.uid()` / sessione corrente)
2. **L’altro account** come indirizzo: `username` (Alfred) oppure `username@server` (esterno)

Niente `thread_id` lato client. Niente entità «casella verso Paolo» esposta come id separato: è **ottimizzazione interna** al server (indici, cache, raggruppamento). Il client continua come oggi: indirizzo → chat.

«In/out» in UI = messaggi nel **mio** archivio dove `author_id` è me (uscita) o l’altro (entrata). Nessuna colonna `direction` nel DB.

---

## Principi confermati

1. **Nessuna conversazione condivisa** — due archivi indipendenti (analogia email).
2. **Nessun allineamento obbligatorio** tra il mio archivio e quello del peer.
3. **Solo `author_id`** — niente `direction` in schema.
4. **Il mio archivio alimenta la mia interfaccia** — casella = dove vivono i messaggi dell’owner, non cache su tabella condivisa.
5. **Outbox sempre** — anche internal passa da outbox; internal / xmpp / matrix differiscono solo nel driver di consegna in fondo. Un solo flusso invio → outbox → archivio destinatario.

## Fuori scope (per ora)

- Delete chat locale
- Gruppi
- Preservazione dati in migrazione (solo DB dev; niente prod)

## Delegato all’implementazione

- Correlazione tra le due copie dello stesso invio (es. `logical_message_id` + `client_message_id`) — scegliere al momento, non vincolare il design concettuale.

---

## Migrazione

Quando si implementa: **migra e basta** — DB solo dev, niente produzione da preservare. Niente doppia scrittura obbligatoria.

---

## Storico

- 2026-06-26: idea da sessione design (cronologia per owner, omogeneità col federato).
- 2026-06-27: su `main` implementato message-centric (PR #130) — percorso diverso, temporaneo.
- 2026-06-28: direzione caselle confermata; specifica lunga sostituita da questa nota; Q&A utente su identità e scope; **outbox sempre** (anche internal) confermato.

---

## Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [address-based-messaging.md](../decisions/address-based-messaging.md) | Modello **attuale** su `main` (da sostituire) |
| [messages-only-inbox.md](../implementation/messages-only-inbox.md) | Implementazione attuale |
| [alpha-full-stack.md](./alpha-full-stack.md) | Flussi Alpha da riusare |
| [server-as-reception.md](../decisions/server-as-reception.md) | Spunte |
| [bridge-stateless.md](../decisions/bridge-stateless.md) | Outbox / bridge (se/un quando) |
