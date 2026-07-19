# Modello caselle (mailbox) — implementato

**Ultima revisione**: 2026-07-19  
**Status**: ✅ **Implementato su `main`** (PR #159; gruppi #162; delivery plane #179) — promesse `SYS-MAILBOX`, `SYS-ACCOUNT-BOUNDARY`, `SYS-DELIVERY` `implemented`  
**Audience**: AI / implementazione

**Su `main`** vale il modello caselle descritto qui e nelle promesse SDD. L’ADR [address-based-messaging.md](../decisions/address-based-messaging.md) resta riferimento per indirizzamento e rubrica isolata.

---

## Modello attuale (implementato)

| Aspetto | Comportamento su `main` |
|---------|-------------------------|
| **Archivio** | Un archivio per owner: ogni utente ha le proprie righe `messages` (`owner_id`) |
| **Confine account** | RPC account toccano **solo** il proprio archivio — [SYS-ACCOUNT-BOUNDARY](../specs/promises/system/SYS-ACCOUNT-BOUNDARY.md) |
| **Consegna** | **Outbox sempre** → worker `alfred_delivery.process_outbox` materializza destinatario e date spunte mittente — [SYS-DELIVERY](../specs/promises/system/SYS-DELIVERY.md) |
| **Inbox** | Lista derivata dal **mio** archivio via `list_inbox()` |
| **Storico chat** | Finestra recente via `list_peer_messages` (ultimi N, default 100); pagine più vecchie con cursore `p_before_created_at`; anteprima inbox ⊆ prima finestra (SYS-MAILBOX-057) |
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
5. **Outbox sempre** — anche internal passa da outbox; internal / xmpp / matrix differiscono solo nel driver di consegna in fondo.
6. **Spunte = segnali puntuali** — aggiornano solo la copia del mittente tramite id di correlazione; **non** sincronizzano né modificano l’archivio del peer (modello federato).
7. **Confine account** — nessuna RPC account attraversa l’archivio altrui; solo worker `alfred_delivery` (infrastruttura, non account).

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
| Job outbox | `outbox.id` + `event_kind` |
| Segnale `delivered` / `read` | `(owner_id mittente, logical_message_id)` |
| Bridge federato (inbound ack) | `external_id` + protocollo → risoluzione su λ |

`client_message_id` e `logical_message_id` restano **sempre** distinti: il primo è solo invio, il secondo solo correlazione e recapito.

## Consegna — stessa pipeline ovunque (vincolante)

Internal e federato condividono **un solo tipo** di recapito; differisce solo il driver in fondo (worker internal sincrono vs bridge async).

| Fase | Attore | Effetto |
|------|--------|---------|
| **Accettazione** | RPC account mittente | INSERT copia mittente → UI ✓ |
| **Accodamento** | RPC account mittente | INSERT `outbox` (`event_kind = deliver`) |
| **Recapito** | Worker `alfred_delivery` | Gate allow list destinatario → INSERT copia destinatario |
| **Ack consegnato** | Worker `alfred_delivery` | UPDATE `delivered_at` su copia mittente (✓✓ grigie) |

Su internal il worker gira **nella stessa transazione** della RPC mittente (sincrono per l’utente). Non è uno shortcut da eliminare: è il contratto [SYS-DELIVERY](../specs/promises/system/SYS-DELIVERY.md).

### Stati operativi

- **Retry** outbox — stesso meccanismo internal e federato
- **`failed` / dead-letter** se esauriti i tentativi
- **UI mittente**: resta su ✓ finché non arriva il segnale `delivered`; assenza di ✓✓ = consegna in corso, rifiuto allow list o fallita — non «messaggio perso»

## Spunte — segnali, non sync archivi (vincolante)

Nel federato **non esiste** una riga condivisa tra mittente e destinatario. Ogni lato ha il proprio archivio; le spunte si risolvono con **segnali separati** che **referenziano** il messaggio originale per id — non aggiornando la copia altrui dall’RPC account.

Alfred caselle usa lo **stesso modello** anche tra due utenti sulla stessa istanza (internal), con worker `alfred_delivery` come unico attraversamento confine.

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
| Inviato | ✓ | Accettato da piattaforma / in outbox | Copia mittente creata | Outbox `queued` |
| Consegnato | ✓✓ grigie | Nella fonte di verità del destinatario | Worker `deliver` → `delivered_at` mittente | XEP-0184 / ack bridge → stesso aggiornamento |
| Letto | ✓✓ blu | Destinatario ha visualizzato | `mark_peer_read` locale → outbox `read_receipt` → worker → `read_at` mittente | XEP-0333 / m.receipt → bridge |

**Non** significa «arrivato sul device» in senso P2P: significa «nella fonte di verità rilevante» (server / piattaforma).

### Regole

- Il segnale aggiorna **solo** `delivered_at` / `read_at` sulla **copia del mittente** identificata da `logical_message_id` (+ `owner_id` mittente), tramite **worker** — mai da RPC account cross-boundary.
- **Mai** modificare l’archivio del peer per far vedere le spunte al mittente.
- **Mai** allineare preview, ordine o contenuto tra le due copie come effetto delle spunte.
- Realtime mittente: subscribe agli UPDATE sulla **propria** copia (`owner_id = io`); merge optimistic via `client_message_id`, spunte via `logical_message_id`.
- I marker non vanno «all’indietro» (segnale su id più vecchio dello stato locale → ignorare).

### Flusso internal (sintesi)

```
Invio (account mittente)
  → INSERT copia mittente (λ) — ✓
  → INSERT outbox (event_kind=deliver)
  → alfred_delivery.process_outbox:
       gate reception_allowlist(destinatario)
       SE allowed: INSERT copia destinatario + delivered_at mittente — ✓✓ grigie
       ALTRIMENTI: reception_rejected, delivered_at null — ✓ permanente

Paolo apre chat (account Paolo)
  → mark_peer_read: UPDATE read_at solo archivio Paolo
  → outbox read_receipt per ogni λ
  → worker: UPDATE read_at copia Mario — ✓✓ blu
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

**Gruppi** — account `profile_kind = group`, erogazione via worker, shell dedicata. Vedi [groups.md](../guides/groups.md) e promessa `SYS-GROUP`.

---

## Migrazione

Quando si implementa: **migra e basta** — DB solo dev, niente produzione da preservare. Niente doppia scrittura obbligatoria.

---

## Storico

- 2026-06-26: idea da sessione design (cronologia per owner, omogeneità col federato).
- 2026-06-27: su `main` implementato message-centric (PR #130) — percorso diverso, temporaneo.
- 2026-06-28: direzione caselle confermata; Q&A identità, outbox sempre, media condivisi/GC, **spunte = segnali** (modello XMPP/Matrix) confermato.
- 2026-06-29: identificatori a livelli distinti (`id` / `client_message_id` / λ / `external_id`), idempotenza per operazione, consegna parziale = stato normale pipeline.
- 2026-07-04: discovery chiuso; promessa `SYS-MAILBOX` approved; spunte = `delivered_at`/`read_at` (no enum status).
- 2026-07-04: gate `SYS-RECEPTION` (#161) nel driver internal — recapito condizionato.
- 2026-07-11: **#179** — `SYS-ACCOUNT-BOUNDARY` + `SYS-DELIVERY`; worker `alfred_delivery`; RPC account solo confine proprio.
- 2026-07-19: **#210** — `list_peer_messages` finestra recente + cursore paginazione; SYS-MAILBOX-036/057; SURF-CHAT-015.

---

## Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [address-based-messaging.md](../decisions/address-based-messaging.md) | Indirizzamento e rubrica isolata (vincolante) |
| [full-stack.md](./full-stack.md) | Flussi attuali da riusare |
| [server-as-reception.md](../decisions/server-as-reception.md) | Spunte |
| [SYS-ACCOUNT-BOUNDARY.md](../specs/promises/system/SYS-ACCOUNT-BOUNDARY.md) | Legge madre confine account |
| [SYS-DELIVERY.md](../specs/promises/system/SYS-DELIVERY.md) | Worker outbox + contratto spunte |
| [SYS-RECEPTION.md](../specs/promises/system/SYS-RECEPTION.md), [PROM-RECEPTION-FILTER.md](../specs/promises/product/PROM-RECEPTION-FILTER.md), [SURF-ALLOWLIST.md](../specs/surfaces/SURF-ALLOWLIST.md) | Gate recapito nel worker |
| [bridge-stateless.md](../decisions/bridge-stateless.md) | Outbox / bridge (se/un quando) |
| [contracts/schema.md](../specs/contracts/schema.md) · [contracts/rpc.md](../specs/contracts/rpc.md) | Dettaglio DDL/RPC |
