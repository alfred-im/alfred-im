# Modello caselle (mailbox) — implementato

**Ultima revisione**: 2026-09-15  
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

## Media (GIF, voice, image, video) — ingest al recapito

### Principio (target vincolante)

Ogni **copia archivio** possiede il proprio blob in `chat-media` (path sotto `{archive_user_id}/…`). Il destinatario **non** riusa il puntatore del mittente. Solo **testo** e **location** (coordinate in Postgres) non richiedono ingest binario.

Promessa: [SYS-MAILBOX-009](../specs/promises/system/SYS-MAILBOX.md) — amend: un blob per copia archivio; ingest al recapito.

### Flusso mittente (sempre)

```text
1. Client: upload → bucket chat-media nel namespace mittente ({auth.uid()}/{uuid}.*)
2. RPC send: INSERT copia mittente con media_url locale (archivio mittente)
3. INSERT outbox (event_kind=deliver) con snapshot contenuto + riferimento blob mittente
```

### Modulo erogazione → ingresso inbox unificato

Dopo gate reception, il worker di erogazione materializza il blob **prima** della copia destinatario. Internal ed external convergono sullo **stesso** helper: messaggio + `media_url` **già locale** sul destinatario. La inbox non distingue il ramo.

| Ramo | Trigger | Egress media | Risultato inbox destinatario |
|------|---------|--------------|----------------------------|
| **Internal** | `peer_address` su stessa istanza | Copia server-side blob mittente → `{destinatario_uid}/{uuid}.*` (stesso Supabase, niente HTTP) | `media_url` locale |
| **External (Gotham)** | `@server` remoto | Mint **URL temporizzato** (`media_fetch_url`) sul blob mittente → wire | Peer: fetch HTTP → ingest in namespace destinatario → `media_url` locale |

Wire: [gotham-protocol.md](./gotham-protocol.md) § 3.1 Media.

### Garbage collection (target)

- Un blob per copia archivio: eliminare una riga messaggio non cancella il blob se altre righe **nello stesso archivio** referenziano lo stesso `media_url`.
- Blob orfani (upload ok, recapito mai materializzato): edge case da contare nel GC.
- Delete account / purge: ogni titolare rimuove solo i propri blob.

### Stato implementazione (`main`) — transitorio

| Aspetto | Oggi | Target (questa spec) |
|---------|------|------------------------|
| Recapito locale | Copia solo puntatore `media_url` mittente (`_insert_recipient_copy`) | Copia blob in namespace destinatario |
| Federazione | Bloccante (URL remoto non leggibile) | `media_fetch_url` + ingest inbound |
| Bucket policy | `chat_media_select_authenticated` su tutto il bucket — maschera il debito locale | Isolamento per `{archive_user_id}/` |

Fino alla migrazione: il codice segue ancora il modello a puntatore condiviso; la federazione media resta bloccata.

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

Locale e federato condividono **outbox unificata** e **spunte unificate**; l’unica biforcazione è l’**erogazione** (internal vs Gotham). Vedi [gotham-protocol.md](./gotham-protocol.md) § 5.0.

| Strato | Unificato? | Ruolo |
|--------|------------|--------|
| **Outbox** | Sì | Una coda per `deliver`, `read_receipt`, `reaction_fact`, … |
| **Spunte** | Sì | Un modulo applica `delivered_at` / `read_at` sulla copia mittente — non duplicato in internal vs Gotham |
| **Erogazione** | Diviso | **Internal** (stesso DB) o **Gotham** (HTTP verso altra istanza) |

| Fase | Attore | Effetto |
|------|--------|---------|
| **Accettazione** | RPC account mittente | INSERT copia mittente → UI ✓ |
| **Accodamento** | RPC account mittente | INSERT `outbox` (`event_kind = deliver`) |
| **Erogazione** | Worker internal **o** worker Gotham | Gate allow list destinatario → INSERT copia destinatario (locale o su peer) |
| **Ack consegnato** | Modulo spunte unificato | UPDATE `delivered_at` su copia mittente (✓✓ grigie) — **dopo** erogazione ok |

Sulla stessa istanza l’erogazione internal gira **nella stessa transazione** della RPC mittente (sincrono per l’utente). Non è uno shortcut da eliminare: è il contratto [SYS-DELIVERY](../specs/promises/system/SYS-DELIVERY.md). Federato: erogazione Gotham async; ✓✓ solo dopo HTTP 2xx dal peer.

### Stati operativi

- **Retry** outbox — stesso meccanismo locale e federato
- **`failed` / dead-letter** se esauriti i tentativi
- **UI mittente**: resta su ✓ finché non arriva il segnale `delivered`; assenza di ✓✓ = consegna in corso, rifiuto allow list o fallita — non «messaggio perso»

## Spunte — segnali, non sync archivi (vincolante)

Nel federato **non esiste** una riga condivisa tra mittente e destinatario. Ogni lato ha il proprio archivio; le spunte si risolvono con **segnali separati** che **referenziano** il messaggio originale per id — non aggiornando la copia altrui dall’RPC account.

Alfred caselle usa lo **stesso modello** anche tra due utenti sulla stessa istanza (locale). L’attraversamento confine account passa dall’erogazione (internal o Gotham) e dal modulo spunte unificato — non da RPC account cross-boundary.

### Correlazione

Vedi [Identificatori](#identificatori--livelli-distinti-vincolante). In sintesi:

| Ruolo | Locale (stessa istanza) | Federato (altra istanza) |
|-------|-------------------------|-------------------|
| Correlazione copie + spunte | `logical_message_id` | `logical_message_id` |
| Evento lettura | `read_receipt_id` | `read_receipt_id` (wire READ) |
| Evento reaction | `reaction_fact_id` | `reaction_fact_id` (wire REACTION) |
| Copia mittente | Archivio uscita (`author_id = io`) | Archivio uscita lato Alfred |
| Copia destinatario | Erogazione internal | Erogazione Gotham inbound (`materialize_inbound_sender_message`) |

Contratto wire: [gotham-protocol.md](./gotham-protocol.md). Il messaggio federato **non** usa `external_id`.

### Tre livelli (semantica [server-as-reception](../decisions/server-as-reception.md))

| Livello | UI | Significato | Locale | Federato |
|---------|-----|-------------|----------|----------|
| Inviato | ✓ | Accettato da piattaforma / in outbox | Copia mittente creata | Outbox `queued` |
| Consegnato | ✓✓ grigie | Nella fonte di verità del destinatario | Erogazione internal ok → modulo spunte | HTTP 2xx peer → modulo spunte |
| Letto | ✓✓ blu | Destinatario ha visualizzato | `mark_peer_read` → outbox `read_receipt` | Evento READ sul wire |

**Non** significa «arrivato sul device» in senso P2P: significa «nella fonte di verità rilevante» (server / piattaforma).

### Regole

- Il segnale aggiorna **solo** `delivered_at` / `read_at` sulla **copia del mittente** identificata da `logical_message_id` (+ `archive_user_id` mittente), tramite il **modulo spunte unificato** (dopo erogazione internal o Gotham) — mai da RPC account cross-boundary. I worker di erogazione **non** duplicano questa logica.
- **Mai** modificare l’archivio del peer per far vedere le spunte al mittente.
- **Mai** allineare preview, ordine o contenuto tra le due copie come effetto delle spunte.
- Realtime mittente: subscribe agli UPDATE sulla **propria** copia (`archive_user_id = io`); merge optimistic via `client_message_id`, spunte via `logical_message_id`.
- I marker non vanno «all’indietro» (segnale su id più vecchio dello stato locale → ignorare).

### Flusso locale (sintesi)

```
Invio (account mittente) — send_message_to_address
  → gate outbound: is_sender_allowed_for_reception(mittente, destinatario)
       SE violazione: raise exception 'recipient not in reception allowlist'
                      — nessuna INSERT copia mittente
  → INSERT copia mittente (λ) — ✓
  → INSERT outbox (event_kind=deliver)
  → erogazione internal (process_outbox → deliver_internal):
       gate inbound: reception_allowlist(destinatario)
       SE allowed: INSERT copia destinatario
       → modulo spunte: delivered_at mittente — ✓✓ grigie
       ALTRIMENTI: reception_rejected, delivered_at null — ✓ permanente

Paolo apre chat (account Paolo)
  → mark_peer_read: UPDATE read_at + mint read_receipt_id solo archivio Paolo
  → outbox read_receipt per ogni λ (payload include read_receipt_id)
  → erogazione (internal o Gotham) + modulo spunte: read_at + read_receipt_id copia Mario — ✓✓ blu
```

Gate allow list: [SYS-RECEPTION.md](../specs/promises/system/SYS-RECEPTION.md), [PROM-RECEPTION-FILTER.md](../specs/promises/product/PROM-RECEPTION-FILTER.md), [SURF-ALLOWLIST.md](../specs/surfaces/SURF-ALLOWLIST.md).

### Flusso federato (target)

Vedi [gotham-protocol.md](./gotham-protocol.md). Sintesi:

```
Invio (account mittente)
  → INSERT copia mittente (logical_message_id mintato) — ✓
  → INSERT outbox (event_kind=deliver, status=queued)
  → worker Gotham claim → POST /gotham/v1/events (envelope MESSAGE)
  → peer HTTP 2xx (erogazione ok)
  → modulo spunte unificato: delivered_at mittente — ✓✓ grigie

Peer segna letto
  → outbox read_receipt → erogazione Gotham outbound
  → POST host istanza mittente originale (READ: from_user=lettore, to_user=mittente, firmatario=istanza lettore)
  → inbound + modulo spunte unificato sulla copia mittente

Peer reagisce
  → POST /gotham/v1/events (REACTION)
  → erogazione inbound → INSERT message_reaction_facts
       reactor_address = fqdn(from_user, signer_im_server_id)
```

Inbound messaggio: `materialize_inbound_sender_message` con `logical_message_id` **dal server mittente remoto** — mai rigenerato.

## Fuori scope (per ora)

- Delete chat locale
- Preservazione dati in migrazione (solo DB dev; niente prod)

**Gruppi** — account `profile_kind = group`; gamba 1 umano→gruppo + gamba 2 gruppo→membro (N outbox `deliver` via `erogate_group_message` / `group_erogate`). Vedi [groups.md](../guides/groups.md) e `SYS-GROUP`.

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
