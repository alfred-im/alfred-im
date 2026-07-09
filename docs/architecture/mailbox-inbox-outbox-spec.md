# Modello caselle (mailbox) — implementato

**Ultima revisione**: 2026-07-09  
**Status**: ✅ **Implementato su `main`** (PR #159; gruppi PR #162) — promessa `SYS-MAILBOX` `implemented`  
**Audience**: AI / implementazione

**Su `main`** vale il modello caselle descritto qui e nella promessa [SYS-MAILBOX](../specs/promises/system/SYS-MAILBOX.md). L’ADR [address-based-messaging.md](../decisions/address-based-messaging.md) resta riferimento per indirizzamento e rubrica isolata.

---

## Modello attuale (implementato PR #159)

| Aspetto | Comportamento su `main` |
|---------|-------------------------|
| **Archivio** | Un archivio per owner: ogni utente ha le proprie righe `messages` (`owner_id`) |
| **Consegna** | **Outbox sempre** (anche internal), poi materializzazione copia destinatario — un solo tipo di pipeline |
| **Inbox** | Lista derivata dal **mio** archivio via `list_inbox()` |
| **Identità chat** | `(io, peer_profile_id)` — indirizzo `username` o `username@server` in compose |

Tutto il resto (UI, realtime, spunte, tipi messaggio, rubrica) si deduce dall’implementazione attuale salvo quanto sotto.

---

## Media (GIF, voice) — file condiviso

Il flusso client resta quello attuale: **un upload** nel bucket `chat-media` → **un** `media_url` → metadati sul messaggio.

Con il modello caselle le **copie d’archivio** (mittente e destinatario) puntano allo **stesso blob** — il file **non** si duplica in storage. È una scelta deliberata (come un allegato referenziato in due caselle), non un dettaglio trascurabile.

### Implicazioni

| Aspetto | Conseguenza |
|---------|-------------|
| **Riferimento** | Più righe `messages` possono condividere lo stesso `media_url` |
| **Garbage collection** | Eliminare un messaggio o una casella **non** implica che il file sia orfano: va verificato se **altre** copie (o altri owner) referenziano ancora quell’URL prima di cancellare da `chat-media` |
| **Delete locale** (futuro) | Cancello la chat dal mio lato → la mia riga sparisce, ma il peer può ancora referenziare lo stesso file |
| **Rimozione lato mittente** | Cancellare il file in storage mentre il destinatario ha ancora il messaggio → **link rotto** per il peer, salvo policy esplicita |
| **Retry / invio fallito** | Upload riuscito ma consegna non materializzata → blob in storage senza (o con) riga archivio — edge case da contare nel GC |
| **Bridge** (futuro) | Il bridge può aver scaricato/cachato dal URL; delete storage non equivale a «revocato» fuori da Alfred |

**Regola:** trattare i media come **risorsa condivisa con refcount logico** (o audit delle referenze), non come proprietà della singola riga archivio. La strategia GC (quando contare le referenze, job async, soft-delete) va definita **prima** di implementare delete messaggi/casella o purge storage — fuori scope attuale ma **non** ignorabile nel design.

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
6. **Spunte = segnali puntuali** — aggiornano solo la copia del mittente tramite id di correlazione; **non** sincronizzano né modificano l’archivio del peer (modello federato).

## Identificatori — livelli distinti (vincolante)

Gli id **non vanno fusi**: ognuno copre un livello diverso. Vale per internal e federazione.

| Id | Scope | Ruolo |
|----|-------|-------|
| **`id` (riga archivio)** | Per owner | Identità **locale** del messaggio nel mio archivio (`owner_id = io`). Mittente e destinatario hanno **sempre** `id` diversi. |
| **`client_message_id`** | Mittente (client + server) | Idempotenza **invio**: retry client, coda outbound, merge UI optimistic lato mittente. **Non** correla le due copie. |
| **`logical_message_id`** | Piattaforma (λ) | **Correlazione** tra le due copie dello stesso invio + target dei segnali spunta (`delivered` / `read`). |
| **`external_id`** | Federato | Id **percepito dall’altro sistema** (XMPP stanza `id`, Matrix `event_id`). Il bridge lo traduce in update sulla copia Alfred del mittente (via λ o mapping esplicito). |

### Regole

- Il client mittente: optimistic su `client_message_id` → poi aggancia alla riga server (`id` della **propria** copia).
- Spunte e bridge: operano su `logical_message_id` (e in federato su `external_id` per interpretare ack del protocollo esterno).
- Il destinatario vede solo il **suo** `id` riga; il mittente non assume mai che coincida col proprio.
- A volte serve l’id **come lo vede l’altro account** (es. XEP-0333 `displayed@id`) — è compito del bridge mapparlo sulla copia corretta lato Alfred, non del client.

### Idempotenza (chiavi di dedup)

| Operazione | Chiave |
|------------|--------|
| Retry invio client | `(owner_id mittente, client_message_id)` |
| Materializzazione copia destinatario | `(owner_id destinatario, logical_message_id)` |
| Job outbox | `logical_message_id` (o `outbox.id` equivalente) |
| Segnale `delivered` / `read` | `(owner_id mittente, logical_message_id)` |
| Bridge federato (inbound ack) | `external_id` + protocollo → risoluzione su λ |

`client_message_id` e `logical_message_id` restano **sempre** distinti: il primo è solo invio, il secondo solo correlazione e recapito.

## Consegna — stessa pipeline ovunque (vincolante)

Internal e federato condividono **un solo tipo** di recapito; differisce solo il driver in fondo (sync sulla stessa istanza vs bridge).

| Fase | Effetto |
|------|---------|
| **Accettazione** | Copia mittente creata → UI ✓ (`sent`) |
| **Recapito** | Outbox → materializzazione copia destinatario |
| **Ack** | Segnale `delivered` sulla copia mittente (via λ) |

Se il recapito non completa (copia mittente sì, destinatario no), **non** è un’anomalia del modello caselle: è uno **stato di consegna** come per email, XMPP o Matrix. Oggi su internal sembra istantaneo solo perché insert + `delivered` sono nella stessa transazione — shortcut da eliminare.

### Stati operativi (da implementare)

- **Retry** outbox — stesso meccanismo internal e federato
- **`failed` / dead-letter** se esauriti i tentativi
- **UI mittente**: resta su ✓ finché non arriva il segnale `delivered`; assenza di ✓✓ = consegna in corso o fallita, non «messaggio perso»

## Spunte — segnali, non sync archivi (vincolante)

Nel federato **non esiste** una riga condivisa tra mittente e destinatario. Ogni lato ha il proprio archivio; le spunte si risolvono con **messaggi/segnali separati** che **referenziano** il messaggio originale per id — non aggiornando la copia altrui.

Alfred caselle usa lo **stesso modello** anche tra due utenti sulla stessa istanza (internal).

### Correlazione

Vedi [Identificatori](#identificatori--livelli-distinti-vincolante). In sintesi:

| Ruolo | Internal Alfred | Federato (riferimento protocollo) |
|-------|-----------------|-----------------------------------|
| Correlazione copie + spunte | `logical_message_id` (λ) | λ + `external_id` (XMPP `id` · Matrix `event_id`) |
| Copia mittente | Riga nel **mio** archivio (`author_id = io`), `id` locale | Archivio uscita lato Alfred |
| Copia destinatario | Riga nel **suo** archivio (`author_id = mittente`), `id` locale | Archivio ingresso / server esterno |

### Tre livelli (semantica [server-as-reception](../decisions/server-as-reception.md))

| Livello | UI | Significato | Internal | Federato |
|---------|-----|-------------|----------|----------|
| Inviato | ✓ | Accettato da piattaforma / in outbox | Copia mittente `sent` | Outbox `queued` |
| Consegnato | ✓✓ grigie | Nella fonte di verità del destinatario | Dopo materializzazione copia destinatario → **segnale** `delivered` sulla copia mittente | XEP-0184 `received@id` o ack bridge → stesso aggiornamento sulla copia mittente Alfred |
| Letto | ✓✓ blu | Destinatario ha visualizzato | `mark_peer_read` sul **proprio** archivio → **segnale** `read` sulla copia mittente (stesso `logical_message_id`) | XEP-0333 `displayed@id` o Matrix `m.receipt` → bridge aggiorna copia mittente |

**Non** significa «arrivato sul device» in senso P2P: significa «nella fonte di verità rilevante» (server / piattaforma).

### Regole

- Il segnale aggiorna **solo** `delivered_at` / `read_at` sulla **copia del mittente** identificata da `logical_message_id` (+ `owner_id` mittente).
- **Mai** modificare l’archivio del peer per far vedere le spunte al mittente.
- **Mai** allineare preview, ordine o contenuto tra le due copie come effetto delle spunte.
- Realtime mittente: subscribe agli UPDATE sulla **propria** copia (`owner_id = io`); merge optimistic via `client_message_id`, spunte via `logical_message_id` — vedi [Identificatori](#identificatori--livelli-distinti-vincolante).
- I marker non vanno «all’indietro» (segnale su id più vecchio dello stato locale → ignorare).

### Flusso internal (sintesi)

```
Invio → copia mittente (λ) — livello ✓ (accettato server)
      → gate reception_allowlist(destinatario)
      → SE allowed: copia destinatario (λ) + delivered_at su mittente — livello ✓✓
      → outbox completed

Paolo apre chat → mark_peer_read sul SUO archivio
               → segnale read sulla copia Mario WHERE logical_message_id = λ
```

Gate allow list: [SYS-RECEPTION.md](../specs/promises/system/SYS-RECEPTION.md), [PROM-RECEPTION-FILTER.md](../specs/promises/product/PROM-RECEPTION-FILTER.md), [SURF-ALLOWLIST.md](../specs/surfaces/SURF-ALLOWLIST.md).

### Flusso federato (sintesi)

```
Alfred → outbox → bridge → server esterno del peer
              → copia mittente su Alfred

Peer legge su client esterno → XEP-0333 / m.receipt
                            → bridge → UPDATE copia mittente Alfred (via external_id / λ)
```

Il bridge è **stateless** ([bridge-stateless.md](../decisions/bridge-stateless.md)): traduce il segnale protocollo in update piattaforma, non tiene stato spunte in RAM.

## Fuori scope (per ora)

- Delete chat locale
- Preservazione dati in migrazione (solo DB dev; niente prod)

**Gruppi** — implementati (PR #162, promessa `SYS-GROUP`): account `profile_kind = group`, erogazione automatica, shell dedicata. Vedi [groups-client.md](../implementation/groups-client.md).

## Delegato all’implementazione

- Dettaglio schema (`delivered_at` / `read_at` su copia mittente), nomi RPC e transazioni dei driver — al momento del codice.
- Driver internal: sync nella stessa RPC vs worker async (non cambia la semantica [Consegna](#consegna--stessa-pipeline-ovunque-vincolante)).

---

## Migrazione

Quando si implementa: **migra e basta** — DB solo dev, niente produzione da preservare. Niente doppia scrittura obbligatoria.

---

## Storico

- 2026-06-26: idea da sessione design (cronologia per owner, omogeneità col federato).
- 2026-06-27: su `main` implementato message-centric (PR #130) — percorso diverso, temporaneo.
- 2026-06-28: direzione caselle confermata; Q&A identità, outbox sempre, media condivisi/GC, **spunte = segnali** (modello XMPP/Matrix) confermato.
- 2026-06-29: identificatori a livelli distinti (`id` / `client_message_id` / λ / `external_id`), idempotenza per operazione, consegna parziale = stato normale pipeline.
- 2026-07-04: discovery chiuso; promessa `SYS-MAILBOX` approved; spunte = `delivered_at`/`read_at` (no enum status); federato UI blocked (scope attuale).
- 2026-07-04: gate `SYS-RECEPTION` (#161) nel driver internal — recapito condizionato; semantica ✓ (accettato) vs ✓✓ (consegnato).

---

## Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [address-based-messaging.md](../decisions/address-based-messaging.md) | Indirizzamento e rubrica isolata (vincolante) |
| [full-stack.md](./full-stack.md) | Flussi attuali da riusare |
| [server-as-reception.md](../decisions/server-as-reception.md) | Spunte |
| [SYS-RECEPTION.md](../specs/promises/system/SYS-RECEPTION.md), [PROM-RECEPTION-FILTER.md](../specs/promises/product/PROM-RECEPTION-FILTER.md), [SURF-ALLOWLIST.md](../specs/surfaces/SURF-ALLOWLIST.md) | Gate recapito destinatario |
| [bridge-stateless.md](../decisions/bridge-stateless.md) | Outbox / bridge (se/un quando) |
