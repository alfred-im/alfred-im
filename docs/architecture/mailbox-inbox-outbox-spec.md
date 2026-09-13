# Modello caselle (mailbox) — implementato

**Ultima revisione**: 2026-09-13  
**Status**: ✅ **Implementato su `main`** (PR #159; gruppi #162; delivery plane #179) — promesse `SYS-MAILBOX`, `SYS-ACCOUNT-BOUNDARY`, `SYS-DELIVERY` `implemented`  
**Audience**: AI / implementazione

**SSOT meccanica mailbox / outbox / worker.** Semantica UI spunte (✓ / ✓✓ / blu): [server-as-reception.md](../decisions/server-as-reception.md). **SSOT indice:** [SSOT.md](../SSOT.md).

L’ADR [address-based-messaging.md](../decisions/address-based-messaging.md) resta riferimento per indirizzamento e rubrica isolata.

---

## Modello attuale (implementato)

| Aspetto | Comportamento su `main` |
|---------|-------------------------|
| **Archivio** | Un archivio per titolare archivio: ogni utente ha le proprie righe `messages` (`archive_user_id`) |
| **Confine account** | RPC account toccano **solo** il proprio archivio — [SYS-ACCOUNT-BOUNDARY](../specs/promises/system/SYS-ACCOUNT-BOUNDARY.md) |
| **Consegna** | **Outbox sempre** → worker `alfred_delivery.process_outbox` materializza destinatario e date spunte mittente — [SYS-DELIVERY](../specs/promises/system/SYS-DELIVERY.md) |
| **Inbox** | Lista derivata dal **mio** archivio via `list_inbox()` |
| **Storico chat** | Finestra recente via `list_peer_messages` (ultimi N, default 100); pagine più vecchie con cursore `p_before_created_at`; anteprima inbox ⊆ prima finestra (SYS-MAILBOX-057) |
| **Identità chat** | `(io, peer_address)` — indirizzo lowercase `username` o `username@server`; presentazione via `get_profiles` |

Tutto il resto (UI, realtime, spunte, tipi messaggio, rubrica) si deduce dall’implementazione attuale salvo quanto sotto.

---

## Media (GIF, voice, image, video) — comportamento attuale e debito isolamento

### Comportamento implementato oggi

Il flusso client: **un upload** nel bucket `chat-media` (path `{uploader_uid}/{uuid}.*`) → **un** `media_url` → metadati sul messaggio.

Il worker `alfred_delivery` alla materializzazione della copia destinatario **non** re-ingesta il blob: copia solo il puntatore `media_url` dalla copia mittente / payload outbox (`_insert_recipient_copy` — `coalesce(payload →> 'media_url', sender.media_url)`). Nessuna duplicazione in storage.

Promessa attuale: [SYS-MAILBOX-009](../specs/promises/system/SYS-MAILBOX.md) — stesso `media_url` su copia mittente e destinatario; un upload, nessuna duplicazione blob.

Su **stessa istanza** il destinatario può comunque scaricare il file perché il bucket `chat-media` è pubblico e la policy `chat_media_select_authenticated` consente SELECT a qualsiasi utente autenticato su **tutto** il bucket — non perché il file viva nel suo namespace.

### Debito architetturale — isolamento storage per titolare archivio

Il modello caselle separa le **righe** `messages` per `archive_user_id`, ma **non** isola i blob allegati: il destinatario resta dipendente dallo storage del mittente (path sotto `{mittente_uid}/`, URL dell’istanza mittente).

| Scenario | Cosa succede oggi |
|----------|-------------------|
| **Locale (stessa istanza)** | Destinatario legge il blob dal path del mittente; funziona finché l’oggetto esiste |
| **Mittente elimina blob o account** | La copia destinatario resta in DB ma il `media_url` può diventare **rotto** — nessuna copia locale di riserva |
| **Delete chat / purge futura** | Rimuovere la riga mittente non implica che il peer abbia una copia propria del file |
| **Federazione (Gotham)** | `media_url` punta allo Storage Supabase **dell’istanza mittente** — l’istanza destinatario non può usarlo senza ingest locale; **bloccante** per media federati |

**Requisito a monte (non implementato, non ancora in SDD):** al recapito (worker locale **e** worker federativo inbound) il sistema dovrebbe **materializzare una copia del blob nello storage dell’istanza / nel namespace del titolare archivio destinatario**, aggiornando `media_url` sulla copia destinatario. Solo il testo e la location (coordinate in Postgres) non richiedono ingest.

Questo è coerente con il principio mailbox «archivi indipendenti»: oggi vale per le righe messaggio, **non** per gli allegati binari.

### Implicazioni finché resta il modello a puntatore condiviso

| Aspetto | Conseguenza |
|---------|-------------|
| **Riferimento** | Più righe `messages` possono condividere lo stesso `media_url` |
| **Garbage collection** | Eliminare un messaggio o una casella **non** implica che il file sia orfano: va verificato se **altre** copie referenziano ancora quell’URL prima di cancellare da `chat-media` |
| **Retry / invio fallito** | Upload riuscito ma consegna non materializzata → blob in storage senza (o con) riga archivio — edge case da contare nel GC |
| **Wire Gotham** | Passare `media_url` sul wire **non basta** senza strategia di fetch + ingest lato ricevente — vedi [gotham-protocol.md](./gotham-protocol.md) § Media |

**Regola provvisoria (stato attuale):** trattare i media come risorsa condivisa con refcount logico. La strategia GC e l’**ingest per copia** vanno definiti **prima** di federazione media, delete chat, o purge storage affidabili.

---

## Identità chat (vincolante)

**Non serve altro** oltre a:

1. **Il mio account** (`auth.uid()` / sessione corrente)
2. **L’altro account** come **`peer_address`**: `username` (stessa istanza) oppure `username@server` (stessa o altra istanza)

Niente `thread_id` lato client. Niente UUID profilo come chiave conversazione. Niente entità «casella verso Paolo» esposta come id separato: è **ottimizzazione interna** al server (indici, raggruppamento). Il client: indirizzo → chat.

### Regole indirizzo (§7.2)

| Input | Significato |
|-------|-------------|
| `mario` | Stessa istanza (bare username) |
| `mario@arkham-im.fly.dev` | Server esplicito (stessa istanza se `@server` = `im_server_id` locale) |
| `mario@blackgate-im.fly.dev` | Altra istanza |

- Input case insensitive; persistenza **sempre lowercase**.
- **`mario` ≠ `mario@<im_server_id>`** — identità, chat, allow list e inbox **distinte** (nessuna fusione).
- Delivery legge `@server` e sceglie driver interno vs Gotham — **non** tipologia chat.

### `author_address` (§7.4–§7.5b)

Sulla copia mittente, `author_address` è l'identità che fa fede nella comunicazione — allineata a ciò che il destinatario vede e al wire Gotham. Scrivendo all'esterno, il mittente usa forma FQDN sulla propria copia.

«In/out» in UI = messaggi nel **mio** archivio dove il mittente (`author_address`) è me (uscita) o la controparte (entrata). Nessuna colonna `direction` nel DB.

---

## Principi confermati

1. **Nessuna conversazione condivisa** — due archivi indipendenti (analogia email).
2. **Nessun allineamento obbligatorio** tra il mio archivio e quello del peer.
3. **Solo `author_id`** — niente `direction` in schema.
4. **Il mio archivio alimenta la mia interfaccia** — casella = dove vivono i messaggi del titolare, non cache su tabella condivisa.
5. **Outbox sempre** — anche il recapito locale passa da outbox; locale vs federato differisce solo nel driver di consegna (worker locale sincrono vs worker federativo).
6. **Spunte = segnali puntuali** — aggiornano solo la copia del mittente tramite id di correlazione; **non** sincronizzano né modificano l’archivio del peer (modello federato).
7. **Confine account** — nessuna RPC account attraversa l’archivio altrui; solo worker `alfred_delivery` (infrastruttura, non account).

## Identificatori — livelli distinti (vincolante)

Gli id **non vanno fusi**: ognuno copre un livello diverso. Vale per recapito locale e federazione.

| Id | Scope | Ruolo |
|----|-------|-------|
| **`id` (riga archivio)** | Per archive_user | Identità **locale** del messaggio nel mio archivio (`archive_user_id = io`). Mittente e destinatario hanno **sempre** `id` diversi. |
| **`client_message_id`** | Mittente (client + server) | Idempotenza **invio**: retry client, coda outbound, merge UI optimistic lato mittente. **Non** correla le due copie. |
| **`logical_message_id`** | Server mittente | Identificativo **globale** del messaggio: assegnato dal **server mittente** all'accettazione dell'invio, **replicato identico** sulla copia destinatario (mai rigenerato dal recapito). Correlazione copie + segnali spunta/reaction. |
| **`external_id`** | Opzionale | Correlazione esterna; il wire usa `logical_message_id` |

### Regole

- Il client mittente: optimistic su `client_message_id` → poi aggancia alla riga server (`id` della **propria** copia).
- Spunte e worker: operano su `logical_message_id`.
- Il destinatario vede solo il **suo** `id` riga; il mittente non assume mai che coincida col proprio.
- A volte serve l’id **come lo vede l’altro account** — il worker federativo lo mappa sulla copia corretta lato Alfred, non il client.

### Idempotenza (chiavi di dedup)

| Operazione | Chiave |
|------------|--------|
| Retry invio client | `(archive_user_id mittente, client_message_id)` |
| Materializzazione copia destinatario | `(archive_user_id destinatario, logical_message_id)` |
| Job outbox | `outbox.id` + `event_kind` |
| Segnale `delivered` / `read` | `(archive_user_id mittente, logical_message_id)` |
| Inbound federato | `logical_message_id` (MESSAGE); `read_receipt_id` (READ); `reaction_fact_id` (REACTION) |

`client_message_id` e `logical_message_id` restano **sempre** distinti: il primo è solo invio, il secondo solo correlazione e recapito.

## Consegna — stessa pipeline ovunque (vincolante)

Locale e federato condividono **un solo tipo** di recapito; differisce solo il driver in fondo (worker locale sincrono vs worker federativo async).

| Fase | Attore | Effetto |
|------|--------|---------|
| **Accettazione** | RPC account mittente | INSERT copia mittente → UI ✓ |
| **Accodamento** | RPC account mittente | INSERT `outbox` (`event_kind = deliver`) |
| **Recapito** | Worker `alfred_delivery` | Gate allow list destinatario → INSERT copia destinatario |
| **Ack consegnato** | Worker `alfred_delivery` | UPDATE `delivered_at` su copia mittente (✓✓ grigie) |

Sulla stessa istanza (locale) il worker gira **nella stessa transazione** della RPC mittente (sincrono per l’utente). Non è uno shortcut da eliminare: è il contratto [SYS-DELIVERY](../specs/promises/system/SYS-DELIVERY.md).

### Stati operativi

- **Retry** outbox — stesso meccanismo locale e federato
- **`failed` / dead-letter** se esauriti i tentativi
- **UI mittente**: resta su ✓ finché non arriva il segnale `delivered`; assenza di ✓✓ = consegna in corso, rifiuto allow list o fallita — non «messaggio perso»

## Spunte — segnali, non sync archivi (vincolante)

Nel federato **non esiste** una riga condivisa tra mittente e destinatario. Ogni lato ha il proprio archivio; le spunte si risolvono con **segnali separati** che **referenziano** il messaggio originale per id — non aggiornando la copia altrui dall’RPC account.

Alfred caselle usa lo **stesso modello** anche tra due utenti sulla stessa istanza (locale), con worker `alfred_delivery` come unico attraversamento confine.

### Correlazione

Vedi [Identificatori](#identificatori--livelli-distinti-vincolante). In sintesi:

| Ruolo | Locale (stessa istanza) | Federato (altra istanza) |
|-------|-------------------------|-------------------|
| Correlazione copie + spunte | `logical_message_id` | `logical_message_id` |
| Evento lettura | `read_receipt_id` | `read_receipt_id` (wire READ) |
| Evento reaction | `reaction_fact_id` | `reaction_fact_id` (wire REACTION) |
| Copia mittente | Archivio uscita (`author_id = io`) | Archivio uscita lato Alfred |
| Copia destinatario | Worker `deliver` | `materialize_inbound_sender_message` |

Contratto wire: [gotham-protocol.md](./gotham-protocol.md). Il messaggio federato **non** usa `external_id`.

### Tre livelli (semantica [server-as-reception](../decisions/server-as-reception.md))

| Livello | UI | Significato | Locale | Federato |
|---------|-----|-------------|----------|----------|
| Inviato | ✓ | Accettato da piattaforma / in outbox | Copia mittente creata | Outbox `queued` |
| Consegnato | ✓✓ grigie | Nella fonte di verità del destinatario | Worker `deliver` → `delivered_at` mittente | HTTP 2xx peer |
| Letto | ✓✓ blu | Destinatario ha visualizzato | `mark_peer_read` → outbox `read_receipt` | Evento READ sul wire |

**Non** significa «arrivato sul device» in senso P2P: significa «nella fonte di verità rilevante» (server / piattaforma).

### Regole

- Il segnale aggiorna **solo** `delivered_at` / `read_at` sulla **copia del mittente** identificata da `logical_message_id` (+ `archive_user_id` mittente), tramite **worker** — mai da RPC account cross-boundary.
- **Mai** modificare l’archivio del peer per far vedere le spunte al mittente.
- **Mai** allineare preview, ordine o contenuto tra le due copie come effetto delle spunte.
- Realtime mittente: subscribe agli UPDATE sulla **propria** copia (`archive_user_id = io`); merge optimistic via `client_message_id`, spunte via `logical_message_id`.
- I marker non vanno «all’indietro» (segnale su id più vecchio dello stato locale → ignorare).

### Flusso locale (sintesi)

```
Invio (account mittente) — send_message_to_profile
  → gate outbound: is_sender_allowed_for_reception(mittente, destinatario)
       SE violazione: raise exception 'recipient not in reception allowlist'
                      — nessuna INSERT copia mittente
  → INSERT copia mittente (λ) — ✓
  → INSERT outbox (event_kind=deliver)
  → alfred_delivery.process_outbox:
       gate inbound: reception_allowlist(destinatario)
       SE allowed: INSERT copia destinatario + delivered_at mittente — ✓✓ grigie
       ALTRIMENTI: reception_rejected, delivered_at null — ✓ permanente

Paolo apre chat (account Paolo)
  → mark_peer_read: UPDATE read_at + mint read_receipt_id solo archivio Paolo
  → outbox read_receipt per ogni λ (payload include read_receipt_id)
  → worker: UPDATE read_at + read_receipt_id copia Mario — ✓✓ blu
```

Gate allow list: [SYS-RECEPTION.md](../specs/promises/system/SYS-RECEPTION.md), [PROM-RECEPTION-FILTER.md](../specs/promises/product/PROM-RECEPTION-FILTER.md), [SURF-ALLOWLIST.md](../specs/surfaces/SURF-ALLOWLIST.md).

### Flusso federato (target)

Vedi [gotham-protocol.md](./gotham-protocol.md). Sintesi:

```
Invio (account mittente)
  → INSERT copia mittente (logical_message_id mintato)
  → INSERT outbox (event_kind=deliver, status=queued)
  → worker federativo claim → POST /gotham/v1/events (envelope MESSAGE)
  → peer HTTP 2xx → delivered_at mittente — ✓✓ grigie

Peer segna letto
  → POST /gotham/v1/events (READ: read_receipt_id + object_logical_message_id)
  → worker inbound → propagate_read_receipt sul mittente locale

Peer reagisce
  → POST /gotham/v1/events (REACTION: reaction_fact_id + object_logical_message_id)
  → worker inbound → INSERT message_reaction_facts
```

Inbound messaggio: `materialize_inbound_sender_message` con `logical_message_id` **dal server mittente remoto** — mai rigenerato.

## Fuori scope (per ora)

- Delete chat locale
- Preservazione dati in migrazione (solo DB dev; niente prod)

**Gruppi** — account `profile_kind = group`, erogazione via worker, shell dedicata. Vedi [groups.md](../guides/groups.md) e promessa `SYS-GROUP`.

---

## Migrazione

Quando si implementa: **migra e basta** — DB solo dev, niente produzione da preservare. Niente doppia scrittura obbligatoria.

Backfill dev:

- `peer_address` da `profiles.username` dove esiste storico `peer_profile_id`
- Federati da `peer_external_address`
- Allow list: `allowed_address` da join `profiles.username` su `allowed_profile_id`
- Contacts: `address` da bare username o `external_address`

Storico `mario` + `mario@<im_server_id>` verso stesso profilo: **restano due conversazioni** (coerente §7.2) — nessuna fusione.

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
| [gotham-protocol.md](./gotham-protocol.md) | Contratto wire federazione (HTTP/3, Protobuf, id, mapping outbox) |
| [contracts/schema.md](../specs/contracts/schema.md) · [contracts/rpc.md](../specs/contracts/rpc.md) | Dettaglio DDL/RPC |
