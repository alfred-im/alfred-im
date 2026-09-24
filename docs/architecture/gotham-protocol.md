# Gotham — protocollo federazione Alfred

**Ultima revisione:** 2026-09-24  
**Stato:** `documented` — wire contract definito; runtime non implementato  
**Audience:** AI / implementazione gateway e erogazione Gotham

**SSOT wire:** [gotham.proto](../specs/contracts/gotham.proto)  
**SSOT piattaforma (mailbox, outbox, id):** [mailbox-inbox-outbox-spec.md](./mailbox-inbox-outbox-spec.md)  
**SSOT indice:** [SSOT.md](../SSOT.md)

Gotham è il protocollo di federazione **nativo** tra istanze Alfred.

---

## 1. Panoramica

| Aspetto | Scelta |
|---------|--------|
| **Nome** | Gotham |
| **Trasporto** | HTTP/3 (QUIC) — terminato su **gateway Fly** per istanza |
| **Payload** | **Protobuf** — vedi [gotham.proto](../specs/contracts/gotham.proto) |
| **Discovery** | `GET /.well-known/gotham` → `GothamDiscovery` (path API inclusi) |
| **Profilo pubblico** | `GET /gotham/v1/users/{username}/profile` · `POST /gotham/v1/profiles` (batch) |
| **Fatti messaggistica** | `POST /gotham/v1/events` — body = `GothamEnvelope` (MESSAGE, READ, REACTION, LOCATION) |
| **Ack eventi** | Solo **codice HTTP** (2xx = accettato dal peer) |
| **Identità wire** | `from_user` / `to_user` bare nel body; **istanza mittente** = firma; **istanza destinataria** = HTTP Host |
| **Backend istanza** | Supabase (outbox unificata + erogazione internal via `alfred_delivery`) |
| **Federazione** | Gateway Fly HTTP/3 + worker Gotham — **solo erogazione external** (da implementare) |

Il client Flutter **non** parla Gotham direttamente: parla sempre con la propria piattaforma (RPC Supabase). Sul wire emette/riceve **solo** il worker Gotham (modulo di erogazione verso altra istanza).

**Termine «worker» in questo documento:** indica **solo** il modulo che **eroga** un lavoro outbox verso il destinatario (internal = stesso DB, Gotham = HTTP verso peer). **Non** indica outbox né spunte — vedi § 5.0.

---

## 2. Identificatori

### 2.1 Regola generale

Ogni fatto ha **un nome preciso**. Non esistono campi generici `event_id` o `external_id` sull’envelope Gotham.

| Fatto | Campo id | Chi lo assegna | Quando |
|-------|----------|----------------|--------|
| **Messaggio** (testo, media, location) | `logical_message_id` | Server **mittente** | Accettazione invio (`send_message_to_address`) |
| **Lettura** | `read_receipt_id` | Server **lettore** | `mark_peer_read` |
| **Reaction** | `reaction_fact_id` | Server **chi reagisce** | Accettazione reaction (`apply_message_reaction` / worker) |

Il **client non minta** id federativi: chiede l’azione; il server genera l’UUID e lo persiste.

### 2.2 Messaggio vs oggetto

| Tipo evento | Ha un oggetto (messaggio preesistente)? | Id federativo principale |
|-------------|----------------------------------------|--------------------------|
| **MESSAGE** | No — **crea** il messaggio | `logical_message_id` nel payload |
| **LOCATION** | No — come MESSAGE | `logical_message_id` nel payload |
| **READ** | Sì — il messaggio letto | `read_receipt_id` nel payload; oggetto in `object_logical_message_id` |
| **REACTION** | Sì — il messaggio reagito | `reaction_fact_id` nel payload; oggetto in `object_logical_message_id` |

`object_logical_message_id` sull’envelope root compare **solo** per READ e REACTION.

**MESSAGE e LOCATION non hanno un id «evento» separato.** `logical_message_id` **è** l’identificativo federativo del messaggio: non esiste un secondo campo accanto (niente `event_id` generico). Solo READ e REACTION mintano un id evento aggiuntivo (`read_receipt_id`, `reaction_fact_id`) perché agiscono su un messaggio già esistente.

### 2.3 Retry e deduplicazione

Il worker Gotham, in caso di retry, rimanda lo **stesso POST** con gli **stessi identificativi di dominio**:

| `kind` | Id usato per dedup lato ricevente |
|--------|-----------------------------------|
| MESSAGE / LOCATION | `logical_message_id` |
| READ | `read_receipt_id` |
| REACTION | `reaction_fact_id` |

Non esiste un id «pacchetto HTTP» separato: la deduplicazione è sugli id federativi del fatto.

### 2.4 Cosa non va sul wire Gotham

| Campo | Motivo |
|-------|--------|
| `client_message_id` | Solo idempotenza invio lato client mittente; non correla le copie archivio |
| `messages.id` (riga archivio) | Locale per `archive_user_id`; diverso tra mittente e destinatario |

### 2.5 `messages.external_id` (DB Alfred, opzionale)

Colonna DB riservata per correlazione con sistemi esterni. **Gotham nativo** usa `logical_message_id`, `read_receipt_id`, `reaction_fact_id` — non `external_id`.

---

## 3. Envelope wire

Fonte protobuf: [gotham.proto](../specs/contracts/gotham.proto).

### 3.0 Identità sul wire (vincolante)

Sul wire gli utenti sono **solo bare username** nel body. Le istanze non si ripetono come `user@server` nell’envelope.

| Ruolo | Dove vive | Esempio Paolo@Blackgate → Mario@Arkham |
|-------|-----------|----------------------------------------|
| **Utente mittente / attore** | `from_user` nel body | `paolo` |
| **Utente destinatario** | `to_user` nel body | `mario` |
| **Istanza che invia** (agisce per conto di `from_user`) | **Firma** dell’envelope + `public_keys` in discovery | Blackgate |
| **Istanza che riceve** | **HTTP Host** della richiesta | `arkham-im.fly.dev` |

Il server **non è** l’utente: **certifica** che `from_user` ha compiuto l’azione (messaggio, lettura, reaction), come un notaio federativo.

**Indirizzo canonico DB** (costruito in ingest, non sul wire):

```text
fqdn(user, im_server_id) = lower(user) + "@" + lower(im_server_id)
```

Esempi ingest su Arkham, firma verificata di Blackgate:

| Campo DB | Valore |
|----------|--------|
| `peer_address` / `author_address` (MESSAGE inbound) | `fqdn(from_user, blackgate_im_server_id)` → `paolo@blackgate-im.fly.dev` |
| Gate `allowed_address` | stesso FQDN costruito da `from_user` + istanza firmataria |

**Simmetria messaggio / lettura:**

| Direzione | Host HTTP | Firmatario | `from_user` | `to_user` |
|-----------|-----------|------------|-------------|-----------|
| Messaggio (Paolo → Mario) | Arkham | Blackgate | `paolo` | `mario` |
| Lettura (Paolo ha letto) | Arkham | Blackgate | `paolo` | `mario` |

La lettura usa lo **stesso schema** del messaggio, con verso invertito a livello di effetto (aggiorna la copia **mittente** di `to_user` sul host destinatario).

**Firma:** obbligatoria in produzione — senza verifica istanza un bare `from_user` non è attendibile. Body POST eventi = `GothamSignedEvent` (envelope + `signature`).

### 3.1 Root comune

```text
GothamSignedEvent (body POST /gotham/v1/events)
  envelope                     GothamEnvelope
  signature                    bytes

GothamEnvelope
  kind                         EventKind
  from_user                    string   (bare username, lowercase)
  to_user                      string   (bare username destinatario sull'host HTTP)
  object_logical_message_id    string?  (solo READ / REACTION)
  payload                      oneof
```

### 3.2 Per tipo

#### MESSAGE

```text
kind = MESSAGE
object_logical_message_id: assente

MessagePayload:
  logical_message_id    // id globale messaggio (server mittente) — unico id federativo
  body
  content_type          // text | gif | voice | image | video (non "location" — vedi sotto)
  media_fetch_url?      // capability temporizzata sul blob mittente — NON media_url permanente
  duration_seconds?
  media_mime?
  media_size_bytes?
```

#### READ

```text
kind = READ
object_logical_message_id: uuid del messaggio letto

ReadPayload:
  read_receipt_id       // id evento lettura (server lettore)
  read_at_unix_ms
```

#### REACTION

```text
kind = REACTION
object_logical_message_id: uuid del messaggio reagito

ReactionPayload:
  reaction_fact_id      // id fatto reaction (server reagente)
  kind                  // APPLIED | WITHDRAWN
  emoji?                // obbligatorio se APPLIED; assente se WITHDRAWN
```

#### LOCATION

```text
kind = LOCATION
object_logical_message_id: assente

LocationPayload:
  logical_message_id    // come MESSAGE — unico id federativo
  body?
  latitude
  longitude
```

**Perché `LOCATION` è un `EventKind` separato:** sul wire la posizione ha payload dedicato (lat/lng). In DB Alfred `message_content_type` include `location`; il worker mappa `EventKind.LOCATION` → `content_type = location` in ingest.

### 3.3 Media — egress (mittente) e ingest (destinatario)

Allegati binari (`gif`, `voice`, `image`, `video`): il wire **non** trasporta il blob né il `media_url` permanente del mittente.

**Outbound (worker Gotham sulla istanza mittente):**

```text
1. Blob già in chat-media (namespace mittente) — upload client prima dell'RPC
2. Alla claim outbox deliver: mint media_fetch_url (capability a scadenza, scope λ + peer)
3. POST /gotham/v1/events — MessagePayload con metadati + media_fetch_url
```

**Inbound (worker Gotham sulla istanza destinatario):**

```text
1. Verifica firma + allow list (come ogni evento)
2. GET media_fetch_url → salva blob in chat-media/{destinatario_uid}/…
3. materialize_inbound_sender_message con media_url LOCALE destinatario
```

**Internal (stessa istanza):** nessun wire — il worker internal copia server-side il blob nel namespace destinatario, poi stesso helper di materializzazione inbox. Vedi [mailbox-inbox-outbox-spec.md](./mailbox-inbox-outbox-spec.md) § Media.

La capability deve restare valida per la finestra di retry outbox / re-invio Gotham.

---

## 4. HTTP

### 4.0 Host federativo — `im_server_id` (vincolante)

Il wire Gotham **non** usa `publicBaseUrl` (hosting del client Flutter/PWA). Tutte le interazioni del protocollo federativo avvengono sull’host **`im_server_id`** dell’istanza — lo stesso dominio che compare dopo la `@` negli indirizzi IM (`mario@im.example`).

| Config | Ruolo | Sul wire Gotham? |
|--------|--------|------------------|
| `im_server_id` | Identità istanza IM; parte `@server` negli indirizzi | **Sì** — host dell’API Gotham (discovery, profilo, eventi) |
| `publicBaseUrl` | Dove l’utente apre il client web (può essere white-label, es. `https://app.repubblica.it/chat`) | **No** — solo client; niente account né federazione |

**Risoluzione peer:** da `paolo@blackgate-im.fly.dev` → base `https://blackgate-im.fly.dev` (normalizzato lowercase). API Gotham (unica superficie federativa):

```text
https://{im_server_id}/.well-known/gotham
https://{im_server_id}/gotham/v1/users/{username}/profile
https://{im_server_id}/gotham/v1/profiles
https://{im_server_id}/gotham/v1/events
```

`publicBaseUrl` e `im_server_id` **possono** coincidere (demo Arkham/Blackgate su `*.fly.dev`) o divergere (client su dominio editoriale, IM su `im.*`). La federazione segue sempre `im_server_id`. Vedi [client/deploy/README.md](../../client/deploy/README.md) § Due indirizzi web.

### 4.1 Discovery

```http
GET https://{im_server_id}/.well-known/gotham HTTP/3
Accept: application/x-protobuf
```

Risposta `200`: body `GothamDiscovery` (protobuf).

Campi minimi:

| Campo | Contenuto |
|-------|-----------|
| `version` | Versione protocollo (es. `"1"`) |
| `public_keys` | Chiavi per firma/verifica `GothamSignedEvent` — **obbligatorio in produzione** (§ 10); vuoto ammesso solo sandbox/dev |
| `events_path` | Path POST fatti messaggistica (default `/gotham/v1/events`) |
| `profile_path_template` | Template GET profilo singolo (default `/gotham/v1/users/{username}/profile`) |
| `profiles_batch_path` | Path POST batch profili (default `/gotham/v1/profiles`) |

Dopo discovery il consumer conosce tutti i path — nessun hardcode obbligatorio oltre ai default.

### 4.2 Profilo pubblico

Lettura **sincrona** on-demand (non passa da outbox). Allinea [SYS-PROFILE](../specs/promises/system/SYS-PROFILE.md) SYS-PROFILE-009–010 e `get_profiles` locale.

| Regola | Dettaglio |
|--------|-----------|
| Visibilità | Profilo **pubblico** — **non** gated da allow list del richiedente |
| Shadow | Il peer **non** INSERT in `profiles` locale; risposta wire → RPC `get_profiles` |
| `{username}` | Solo bare username; l’host è `im_server_id` (equivalente a `mario@arkham-im.fly.dev` su host `arkham-im.fly.dev`) |
| Batch | `POST /gotham/v1/profiles` — body `usernames[]` bare; host HTTP = `im_server_id` |
| Assente | Utente inesistente su quell’istanza → `404` (singolo) o omesso nel batch |
| Avatar / cover | URL possono puntare allo Storage **dell’istanza origine** — ingest federato avatar/cover: **filo separato** (fuori scope § 3.3 media chat) |

#### Singolo

```http
GET https://{im_server_id}/gotham/v1/users/{username}/profile HTTP/3
Accept: application/x-protobuf
```

Risposta `200`: body `PublicProfile` (protobuf). `404` se username non esiste.

#### Batch

```http
POST https://{im_server_id}/gotham/v1/profiles HTTP/3
Content-Type: application/x-protobuf

<body: ProfileBatchRequest>
```

Risposta `200`: body `ProfileBatchResponse`. Ordine non garantito; indirizzi non trovati omessi.

#### Integrazione `get_profiles` (piattaforma)

Quando `get_profiles(p_addresses)` riceve indirizzi con `@server` remoto:

1. Raggruppa per `im_server_id` (parte dopo `@`).
2. Per ogni istanza peer: `POST https://{im_server_id}/gotham/v1/profiles` con `usernames[]` bare (o GET singoli).
3. Merge nel result set RPC; ogni risposta espone `address` = `fqdn(username, im_server_id)`; assente → fallback solo `address` richiesto.

Il **client Flutter non chiama Gotham** — solo la piattaforma (implementazione `get_profiles` / gateway).

### 4.3 Invio evento (fatti messaggistica)

```http
POST https://{im_server_id_destinatario}/gotham/v1/events HTTP/3
Content-Type: application/x-protobuf

<body: GothamSignedEvent>
```

`im_server_id` nell’URL = istanza di **`to_user`** (destinatario dell’evento). Il firmatario è l’istanza di **`from_user`** (verificata via `signature` + discovery).

| Codice | Significato |
|--------|-------------|
| `2xx` | Evento accettato e processato (o già visto — dedup idempotente) |
| `4xx` | Rifiuto permanente (malformato, indirizzo sconosciuto, …) |
| `5xx` | Errore temporaneo — il worker può ritentare con **gli stessi id** |

**Non** esiste body di ack strutturato: read e reaction sono **eventi separati**, non embedded nell’ack del MESSAGE.

**Enum proto3:** `EVENT_KIND_UNSPECIFIED` e `REACTION_KIND_UNSPECIFIED` esistono solo per compatibilità protobuf. Sul wire **non** vanno usati; il peer rifiuta envelope con kind non riconosciuto.

### 4.4 Indirizzi

**Piattaforma / DB / UI:** `username@server` — vedi [address-based-messaging.md](../decisions/address-based-messaging.md).

**Wire Gotham (eventi):** solo `from_user` / `to_user` bare; istanze da firma (mittente) e Host HTTP (destinatario). Mapping:

| Outbox / `peer_address` | POST eventi |
|-------------------------|-------------|
| `mario@arkham-im.fly.dev` | Host `arkham-im.fly.dev`, `to_user=mario`, firmatario = istanza locale, `from_user` = mittente bare |

**Normalizzazione (vincolante):** username e server case-insensitive; canonico DB = `lower(user)@lower(im_server_id)`.

**Costruzione inbound:** `fqdn(envelope.from_user, signer_im_server_id)` per `peer_address`, `author_address` e gate `allowed_address`.

---

## 5. Mapping Gotham ↔ piattaforma Alfred

### 5.0 Modello recapito — outbox, erogazione, spunte (vincolante)

Tre strati; **solo l’erogazione** si biforca. Outbox e spunte restano **unificati** — nessuna duplicazione di significato né di logica spunte tra internal e external.

| Strato | Unificato? | Ruolo |
|--------|------------|--------|
| **Outbox** | Sì | Una coda per tutti i lavori in uscita (`deliver`, `read_receipt`, `reaction_fact`, …) |
| **Spunte** | Sì | Un solo significato (✓ / ✓✓ / ✓✓ blu) e **un solo modulo** che applica `delivered_at` / `read_at` sulla copia mittente — **non** duplicato nei worker di erogazione |
| **Erogazione** | **Diviso** | Unico fork: **internal** (stesso DB) vs **external** (Gotham / internet verso altra istanza) |

**Worker** (in questo documento) = **solo erogazione**:

| Worker | Quando | Cosa fa |
|--------|--------|---------|
| **Internal** | `peer_address` risolve su istanza locale | Materializza copia destinatario nel DB locale; gate reception sulla destinazione |
| **Gotham** | `@server` in `peer_address` ≠ `im_server_id` locale | Claim job outbox federato; `POST /gotham/v1/events`; sul peer inbound materializza copia destinatario |

Il **router** (dispatcher outbox) legge `@server` in `peer_address` e invoca internal o Gotham. I worker **non** gestiscono spunte in parallelo: a erogazione riuscita invocano il **modulo spunte unificato** (`delivered_at`, `propagate_read_receipt`, …) e completano il job outbox — **una** implementazione, due trasporti.

```text
RPC account → copia mittente (✓) → outbox (lavoro)
                    │
                    ▼
            router (peer_address)
                    │
         ┌──────────┴──────────┐
         ▼                     ▼
  worker internal        worker Gotham
  (DB locale)            (HTTP → peer)
         │                     │
         └──────────┬──────────┘
                    ▼
         modulo spunte unificato → delivered_at / read_at mittente
                    ▼
              outbox completed
```

Semantica spunte: [server-as-reception.md](../decisions/server-as-reception.md). Dettaglio caselle: [mailbox-inbox-outbox-spec.md](./mailbox-inbox-outbox-spec.md) § Consegna / Spunte.

| Gotham `kind` | `outbox.event_kind` | Payload outbox (campi chiave) |
|---------------|---------------------|-------------------------------|
| MESSAGE / LOCATION | `deliver` | `logical_message_id`, snapshot contenuto; **`peer_address`** destinatario (locale o federato) |
| READ | `read_receipt` | `logical_message_id`, `read_receipt_id`; wire: `from_user`=lettore, `to_user`=mittente originale |
| REACTION | `reaction_fact` | `logical_message_id`, `reaction_fact_id`, `kind`, `emoji`, `reactor_address`; wire: `from_user`=reagente, `to_user`=controparte sulla copia da aggiornare |

### 5.1 Outbound (istanza mittente → peer)

```text
1. RPC account
     send_message_to_address(p_peer_address, …)
     → gate outbound allow list (§ 5.4) su p_peer_address
     → INSERT copia mittente (logical_message_id mintato; peer_address = p_peer_address) — ✓
     → INSERT outbox (event_kind=deliver, status=queued)

2. Router su peer_address:
     stessa istanza → worker internal (sincrono in transazione RPC)
     altra istanza   → worker Gotham claim async → POST /gotham/v1/events

3. Erogazione ok (copia destinatario materializzata sul peer, o localmente):
     → modulo spunte unificato: delivered_at sulla copia mittente — ✓✓ grigie
     → outbox completed

   Federato: «erogazione ok» = HTTP 2xx dal peer (messaggio nella fonte di verità destinatario).
   Fino ad allora il mittente resta su ✓.
```

Routing **senza colonna protocol**: il server in `peer_address` (`user@server`) determina worker internal vs Gotham — non tipologia chat.

### 5.2 Inbound (peer → istanza destinatario)

```text
1. Gateway Fly riceve POST /gotham/v1/events

2. Worker Gotham (ingress) verifica firma → `signer_im_server_id`; valida envelope (kind, id dedup)

3. Gate reception (allow list destinatario) — § 5.4
     `allowed_address = fqdn(envelope.from_user, signer_im_server_id)`

4. SE consentito:
       MESSAGE / LOCATION → materialize copia destinatario (`to_user` su host locale)
         peer_address = author_address = fqdn(from_user, signer_im_server_id)
       READ    → modulo spunte: copia mittente di `to_user` dove peer_address = fqdn(from_user, signer)
       REACTION→ INSERT message_reaction_facts
         reactor_address = fqdn(from_user, signer_im_server_id)
         gate partecipazione su λ (indirizzo, non UUID profilo)

5. HTTP 2xx (anche su rifiuto silenzioso allow list — evento processato, nessuna copia)
```

Materializzazione inbound federata: variante **indirizzo-based** su `peer_address` / `author_address` — vedi § 5.4.

### 5.3 Spunte

Modulo **unificato** (§ 5.0): internal e Gotham non implementano logica spunte separata.

| Livello UI | Significato | Piattaforma |
|------------|-------------|-------------|
| ✓ | Accettato server mittente | Copia mittente creata |
| ✓✓ grigie | Nella fonte di verità destinatario | Dopo erogazione ok → `delivered_at` (locale: internal; federato: HTTP 2xx poi modulo spunte) |
| ✓✓ blu | Destinatario ha letto | Outbox `read_receipt` → erogazione (internal o Gotham) → modulo spunte / wire READ |

Semantica UI: [server-as-reception.md](../decisions/server-as-reception.md).

### 5.4 Reception — allow list address-based (con Gotham)

Stessa semantica [SYS-RECEPTION](../specs/promises/system/SYS-RECEPTION.md) del recapito locale, estesa agli indirizzi federati. Ogni titolare archivio consente mittenti tramite **`allowed_address`** (`username` bare o `user@server`). Stesso modello della rubrica (`contacts.address`).

**Piattaforma (implementato):** `reception_allowlist.allowed_address` — vedi [schema.md](../specs/contracts/schema.md).

#### Schema `reception_allowlist`

| Colonna | Uso |
|---------|-----|
| `archive_user_id` | Titolare archivio che filtra |
| `allowed_address` | Mittente consentito — `username` o `user@server` (lowercase) |

**Vincoli:** UNIQUE `(archive_user_id, allowed_address)`; `allowed_address` ≠ indirizzo del titolare archivio.

#### Gate inbound (destinatario riceve da peer remoto)

Condizione recapito federato (equivalente a SYS-RECEPTION-006):

```text
EXISTS reception_allowlist
  WHERE archive_user_id = destinatario_locale
    AND allowed_address = fqdn(envelope.from_user, signer_im_server_id)
```

- Lista vuota → nessun mittente federato passa → nessuna copia destinatario (silenzio verso istanza remota).
- Su rifiuto: **nessuna** INSERT copia destinatario; risposta HTTP **2xx** al peer mittente (evento processato / dedup — non leak del filtro).
- **Non** usare `contacts` come proxy della allow list (SYS-RECEPTION-022).

#### Gate outbound (mittente invia verso peer remoto)

Prima di INSERT copia mittente federata:

```text
EXISTS reception_allowlist
  WHERE archive_user_id = mittente_locale
    AND allowed_address = normalize(p_peer_address)
```

Su violazione: `raise exception 'recipient not in reception allowlist'` — **nessuna** copia mittente (come outbound locale, SYS-RECEPTION-031).

#### RPC invio (piattaforma)

Punto di invio unificato (locale e federato):

```sql
send_message_to_address(
  p_peer_address text,
  … campi contenuto …
) → messages
```

Semantica federata (server di `p_peer_address` ≠ `im_server_id` locale):

1. Normalizza `p_peer_address`; gate outbound § sopra.
2. INSERT copia mittente: `peer_address` = `p_peer_address`, `logical_message_id` mintato.
3. INSERT `outbox` (`event_kind = deliver`, `status = queued`, payload con `peer_address`).
4. **Non** chiama `process_outbox` sincrono — il consumer Gotham claima la riga.

Il client smette di rifiutare il compose verso `user@server` quando Gotham è attivo ([SYS-MAILBOX-030](../specs/promises/system/SYS-MAILBOX.md) revocato per federazione).

#### Materializzazione inbound (copia destinatario)

Helper federato (indirizzo-based):

```sql
alfred_delivery.materialize_inbound_sender_message(
  p_recipient_profile_id uuid,      -- destinatario locale
  p_sender_address text,            -- fqdn(from_user, signer_im_server_id)
  p_sender_message_id uuid,         -- logical_message_id dal server mittente remoto — mai rigenerare
  … snapshot contenuto …
) → messages
```

Riga archivio destinatario:

| Campo | Valore |
|-------|--------|
| `archive_user_id` | destinatario locale |
| `peer_address` | `p_sender_address` |
| `author_address` | `p_sender_address` |
| `logical_message_id` | dal mittente remoto |
| `author_id` | null su ingresso federato (opzionale se profilo locale esiste) |

**Autore senza profilo locale:** il mittente remoto non ha `profiles.id` sulla istanza destinataria. Display da rubrica (`contacts.address`) o da `author_address`; nessun profilo shadow obbligatorio in `profiles`.

#### UI allow list (riferimento superficie)

Allineata a [SURF-ALLOWLIST](../specs/surfaces/SURF-ALLOWLIST.md):

- Aggiunta locale: `search_profiles` → `allowed_address` (bare username).
- Aggiunta federata: form `user@server` → `allowed_address`.
- Lista: display via `get_profiles([allowed_address])` o indirizzo grezzo.

#### READ / REACTION federati sul wire

Stesso schema § 3.0 per tutti i `EventKind`.

**Outbound (lettore su istanza B, mittente originale su istanza A):**

```text
Paolo@B legge messaggio da mario@A
  → outbox read_receipt su B
  → worker Gotham: POST https://{im_server_id_A}/gotham/v1/events
       firmatario: B
       from_user: paolo
       to_user: mario
       READ: object_logical_message_id, read_receipt_id
  → A: gate su fqdn(paolo, B); modulo spunte su copia mittente di mario
```

**Inbound:** gate su `fqdn(from_user, signer)` prima di propagare segnali sulla copia di `to_user`.

**REACTION — identità reagente (no shadow profile):**

```text
Paolo@B reagisce a messaggio di mario@A (λ condiviso)
  → outbox reaction_fact su B
  → worker Gotham: POST https://{im_server_id_A}/gotham/v1/events
       firmatario: B
       from_user: paolo
       to_user: mario
       REACTION: object_logical_message_id, reaction_fact_id, kind, emoji?
  → A: gate su fqdn(paolo, B)
       INSERT message_reaction_facts
         reactor_address = paolo@blackgate-im.fly.dev
         (nessun profiles.id locale per Paolo)
```

Locale: `apply_message_reaction` accoda `reactor_address` canonico del chiamante (stesse regole `author_address`).

---

## 6. Piattaforma Alfred — stato implementazione (`main`)

Prerequisiti piattaforma per Gotham (implementati):

| Requisito | PR / migrazione |
|-----------|-----------------|
| `logical_message_id` mintato dal server mittente, replicato sul destinatario | #264 — `20260905000000_sender_global_message_id.sql` |
| Inbound materialize con id remoto | `materialize_inbound_sender_message` |
| Reaction via outbox | #265 — `20260905120000_reaction_fact_outbox.sql` |
| `reactor_address` (sostituisce `reactor_id` UUID) | Da implementare con federazione — allinea reaction a modello address-based |
| Media ingest al recapito (`media_fetch_url` wire; copia locale internal) | Da implementare — amend SYS-MAILBOX-009 |
| `read_receipt_id` mint lettore → replica mittente | #266 — `20260905140000_read_receipt_id.sql` |

**Con Gotham (da implementare insieme al protocollo):**

| Requisito | Note |
|-----------|------|
| `reception_allowlist.allowed_address` | § 5.4 — **implementato** (locale + federato) |
| `send_message_to_address` | Invio unificato; outbox federato quando server ≠ locale |
| `materialize_inbound_sender_message` | Inbound con `peer_address` / `author_address` |
| Consumer outbox federato + Gotham ingress (HTTP/3) | § 7 |

Bus outbox `event_kind` attivi: `deliver`, `read_receipt`, `reaction_fact`, `group_erogate`, `push_notify`.

**Gruppi (locale, `20260913120000`):** erogazione gruppo→membro passa dallo stesso `event_kind = deliver` del 1:1 — `erogate_group_message` / `group_erogate` sono **orchestratori** che accodano N outbox `deliver`, non percorsi INSERT separati. Vedi § 9.1.

`push_notify` è **solo locale** (piattaforma): accodato dopo erogazione internal riuscita ([SYS-PUSH](../specs/promises/system/SYS-PUSH.md)). **Non** compare mai sul wire federato.

**Nessun campo `protocol`:** il routing è implicito — server in `peer_address` / `allowed_address` / `contacts.address` determina locale vs federato.

---

## 7. Componenti runtime (da implementare)

| Componente | Stato | Ruolo |
|------------|-------|-------|
| **Gateway Fly HTTP/3** | ❌ | Termina QUIC; espone `/.well-known/gotham` e `/gotham/v1/events` |
| **Worker Gotham** (erogazione external) | ❌ | Claim outbox federato; traduce ↔ Protobuf; POST outbound / materialize inbound |
| **Worker internal** (`alfred_delivery`) | ✅ | Erogazione su stesso DB — già in produzione |
| **Modulo spunte unificato** (`alfred_delivery`) | ✅ | `delivered_at`, `propagate_read_receipt`, … — invocato da entrambi i worker |
| **Spec in repo** | ✅ | Questo file + `gotham.proto` |

Il gateway Python in `client/deploy/gateway/` serve solo la shell PWA (branding dinamico) — **non** è il gateway Gotham di questa sezione.

---

## 8. Architettura fisica

```text
┌─────────────┐     RPC      ┌──────────────────┐
│ Flutter web │ ───────────► │ Supabase (istanza)│
└─────────────┘              │ outbox + internal │
                             └────────┬─────────┘
                                      │ claim (erogazione external)
                             ┌────────▼─────────┐
                             │ Worker Gotham     │
                             └────────┬─────────┘
                                      │ HTTP/3 + Protobuf
                             ┌────────▼─────────┐
                             │ Gateway Fly (peer)│
                             └────────┬─────────┘
                                      │
                             ┌────────▼─────────┐
                             │ Supabase (peer)   │
                             └──────────────────┘
```

- **Supabase Edge Functions** non terminano HTTP/3 — il gateway è su Fly.
- Il worker Gotham (erogazione external) è **stateless**: stato autorevole solo su Postgres (outbox, messages, reaction facts).

---

## 9. Scope e fuori scope

| In scope Gotham | Fuori scope |
|-----------------|-------------|
| Messaggistica 1:1 testo + `LOCATION` | |
| Profilo pubblico remoto (`PublicProfile` / batch) | Avatar/cover federati senza strategia ingest (filo separato) |
| **Gruppi** — identità `@username` / `@username@server`; recapito umano→gruppo; erogazione verso partecipanti su allow list (locali e federati, stesso modello `allowed_address`) | Multi-account sul wire |
| `MESSAGE` con media — `media_fetch_url` + ingest locale destinatario (§ 3.3; [mailbox-inbox-outbox-spec.md](./mailbox-inbox-outbox-spec.md) § Media) | E2E encryption |
| READ, REACTION come eventi separati | `push_notify` sul wire |
| HTTP/3 + Protobuf + discovery | Body di ack strutturato |
| Ack MESSAGE = solo HTTP status | |

I gruppi **non** sono fuori scope: seguono lo stesso contratto address-based e la **stessa pipeline `deliver` / `deliver_internal`** della messaggistica 1:1 ([SYS-GROUP](../specs/promises/system/SYS-GROUP.md), [SYS-DELIVERY](../specs/promises/system/SYS-DELIVERY.md)). Partecipazione = allow list bidirezionale su indirizzo (inclusi `user@server`). Entrypoint RPC: `send_message_to_address` (umano→gruppo), `broadcast_message_to_allowlist` (broadcast gruppo). Federato = stesso bus con driver Gotham quando una **gamba** coinvolge un indirizzo su altra istanza. Nessuna tipologia «gruppo locale» vs «gruppo federato» in UI o wire ([no-internal-external-chat-distinction.md](../decisions/no-internal-external-chat-distinction.md)).

### 9.1 Recapito gruppo — due gambe (implementato su `main`)

Ogni messaggio umano→gruppo ha **due gambe** indipendenti sul piano delivery. Le spunte che vede il mittente umano riguardano **solo la gamba 1** ([PROM-GROUP-TICKS](../specs/promises/product/PROM-GROUP-TICKS.md)).

| Gamba | Mittente (copia uscita) | Destinatario | Outbox | Ack (`delivered_at`) |
|-------|-------------------------|--------------|--------|----------------------|
| **1 — umano→gruppo** | Copia mittente umano | Archivio gruppo (inbound, `peer_address` = mittente) | `deliver` (da `send_message_to_address`) | Copia **umana** (✓✓ = gruppo ha ricevuto) |
| **2 — gruppo→membro** | Copia uscita gruppo (`peer_address` = membro) *oppure* riga broadcast unica | Archivio membro (proxy inbound) | `deliver` per ogni membro eleggibile | Copia **uscita gruppo** di quella gamba — **non** la copia umana |

**Gamba 1 (invariata):**

```text
send_message_to_address(gruppo)
  → INSERT copia mittente umano + outbox deliver
  → deliver_internal: INSERT inbound archivio gruppo + delivered_at su copia umana
  → erogate_group_message (orchestratore gamba 2)
```

**Gamba 2 — messaggio umano→gruppo (fanout):**

```text
erogate_group_message
  per ogni allowed_address con gate bidirezionale:
    → INSERT copia uscita gruppo (stesso λ, peer_address = membro)
    → INSERT outbox deliver (message_id = copia uscita)
    → deliver_internal: INSERT proxy su archivio membro + delivered_at su copia uscita gruppo
    → push_notify locale (se membro locale)
```

Gate bidirezionale fallito → skip silenzioso su quel membro; **non** modifica spunte gamba 1.

**Gamba 2 — broadcast gruppo:**

```text
broadcast_message_to_allowlist
  → INSERT unica riga archivio gruppo (peer_address NULL) + outbox group_erogate
  → group_erogate → erogate_group_message (p_fanout_source = riga broadcast)
  per ogni membro eleggibile:
    → outbox deliver (message_id = riga broadcast, recipient_address nel payload)
    → deliver_internal (stesso binario sopra)
```

Le copie uscita fanout su archivio gruppo **non** compaiono nello storico UI gruppo (`list_archive_messages` le filtra); servono solo al tracking delivery gamba 2.

**Federazione (target Gotham):** ogni outbox `deliver` verso `user@server` segue lo stesso consumer federativo del 1:1 — nessun `event_kind` dedicato «gruppo federato». Il worker Gotham claima la riga, invia envelope `MESSAGE` con lo stesso `logical_message_id`, e l’istanza peer materializza il proxy sul membro remoto. Gamba con entrambi gli endpoint locali resta sincrona in transazione come oggi.

**Schema:** UNIQUE `(archive_user_id, logical_message_id, peer_address)` NULLS NOT DISTINCT — consente inbound umano + N uscite membro sullo stesso archivio gruppo ([contracts/schema.md](../specs/contracts/schema.md)).

---

## 10. Sicurezza (target)

| Meccanismo | Stato |
|------------|-------|
| TLS / QUIC | Obbligatorio (HTTP/3) |
| Firma `GothamSignedEvent` con `public_keys` da discovery | **Obbligatorio** in produzione — attesta istanza mittente per `from_user` |
| Host HTTP = istanza destinataria (`to_user`) | Obbligatorio |
| Gate reception su inbound | Obbligatorio — [SYS-RECEPTION](../specs/promises/system/SYS-RECEPTION.md) |

---

## 11. Review modello — decisioni chiuse e domande aperte

Questa sezione traccia l’esito della **review modello** (discussione iterativa obiezione per obiezione). Non è un gate SDD né una checklist di implementazione.

**Indice parallelo:** [domain/federation/README.md](../domain/federation/README.md) (tabella obiezioni #1–#6).

### 11.1 Decisioni chiuse (review #1–#6)

| # | Decisione | Risposta / modello concordato | Dove nel contratto |
|---|-----------|-------------------------------|-------------------|
| 1 | Outbox e spunte: unificate o duplicate per internal/external? | **Unificate.** Una outbox; modulo spunte unico dopo erogazione ok. Worker = **solo erogazione** (internal vs Gotham). | § 5.0 |
| 2 | Host wire: `publicBaseUrl` o `im_server_id`? | **Solo `im_server_id`.** `publicBaseUrl` = hosting client Flutter, fuori dal wire. | § 4.0 |
| 3 | Profilo federato: shadow profile, allow list, o API dedicata? | **`get_profiles` non gated**; peer serve profilo via Gotham GET/POST; **nessun** INSERT in `profiles` locale. | § 4.2 |
| 4 | Indirizzi sul wire: FQDN nel body o bare + firma/Host? | **`from_user` / `to_user` bare**; istanza mittente = firmatario; destinataria = HTTP Host; `GothamSignedEvent` obbligatorio in produzione. Vale per MESSAGE, READ, REACTION, LOCATION. | § 3.0 |
| 5 | Reaction federata: `reactor_id` UUID o indirizzo? | **`reactor_address`** (text, come `author_address`); nessun profilo shadow per il reagente remoto. | § 5.2, [schema.md](../specs/contracts/schema.md) |
| 6 | Media federati: puntatore, push inline, o pull on ingest? | **Ingest al recapito** — blob per copia archivio. Internal: copia server-side; external: `media_fetch_url` temporizzato + fetch inbound. Ingresso inbox **unificato** (messaggio + `media_url` locale). | § 3.3, [mailbox-inbox-outbox-spec.md](./mailbox-inbox-outbox-spec.md) § Media |

### 11.2 Domande aperte (elenco non esaustivo)

**Non è una lista definitiva** — solo quanto emerso finora in review e analisi gap. Una sessione futura può aggiungere domande, riformularle o chiuderle.

#### Review documentale (obiezioni originarie #7+, mai chiuse in discussione)

| # | Domanda aperta | Contesto |
|---|----------------|----------|
| 7 | **Sicurezza wire:** formato firma, byte canonicali dell’envelope da firmare, algoritmo, rotazione `public_keys`, comportamento sandbox vs produzione se discovery è vuota? | § 10 è target minimo; implementazione `GothamSignedEvent` non specificata |
| 8 | **Promesse `SYS-FEDERATION-*`:** quali ID, file spec, smoke SQL e stato registry per il runtime Gotham? | Oggi assenti o placeholder |
| 9 | **Architettura runtime:** claim/polling outbox federato, auth gateway Fly ↔ Supabase, confine service_role, `push_notify` resta solo locale? | Worker Gotham non implementato |
| 10 | **UML / verifica:** le sequence federation e media ingest sono **target** — serve cablaggio `verified` + test end-to-end? | [model/uml/federation/](../model/uml/federation/), `seq-media-ingest-on-delivery.puml` |

#### Codice `main` vs modello documentato (da chiudere prima o in parallelo ordinato al runtime Gotham)

| Domanda aperta | Oggi (`main`) | Target (questo documento + mailbox spec) |
|----------------|---------------|------------------------------------------|
| Media chat al recapito | Worker copia solo puntatore `media_url` mittente | Ingest blob nel namespace destinatario; amend [SYS-MAILBOX-009](../specs/promises/system/SYS-MAILBOX.md) |
| Reaction — identità reagente | `reactor_id` UUID + `reactor_ids[]` in RPC | `reactor_address` text; migrazione + client |
| Registry / promesse SDD | Alcune promesse restano `implemented` con semantica legacy | Allineamento esplicito registry + test dopo migrazione |

#### Specifica incompleta (doc target ma senza numeri o filo dedicato)

| Domanda aperta | Nota |
|----------------|------|
| **TTL `media_fetch_url`** | Deve coprire retry outbox / re-invio Gotham — durata, scope (λ + peer?), comportamento se scade prima dell’ingest? |
| **Avatar / cover federati** | `PublicProfile` espone URL su storage origine; **nessuna** strategia ingest (filo separato da media chat § 3.3) |
| **Gruppi + media federati** | Fan-out verso N membri su istanze remote: un fetch per gamba, dedup blob, ordine erogazione? |
| **Gateway + worker Gotham** | Componenti non in produzione — dipendenze deploy, health, dedup inbound, idempotenza materialize |

---

## 12. Riferimenti

| Documento | Ruolo |
|-----------|-------|
| [mailbox-inbox-outbox-spec.md](./mailbox-inbox-outbox-spec.md) | Modello caselle, outbox, identificatori DB |
| [gotham.proto](../specs/contracts/gotham.proto) | Contratto Protobuf wire |
| [domain/federation/](../domain/federation/) | Contesto DDD federation |
| [SYS-DELIVERY](../specs/promises/system/SYS-DELIVERY.md) | Promesse worker outbox |
| [full-stack.md](./full-stack.md) | Limitazioni attuali stack |

---

## Changelog documento

| Data | Modifica |
|------|----------|
| 2026-09-05 | Prima stesura — envelope senza `event_id` / `external_id`; id federativi nominati; mapping outbox |
| 2026-09-08 | Rimosso `contact_protocol`; routing implicito; solo Gotham come federazione |
| 2026-09-09 | Wire media: ingest locale destinatario obbligatorio — evoluzione → `media_fetch_url` (§ 3.3) |
| 2026-09-09 | § 5.4 — `reception_allowlist` locale + esterna; RPC invio/materialize federato; gate su `fqdn(from_user, signer)` |
| 2026-09-13 | § 5.4 — modello address-based unificato (`peer_address`, `author_address`, `allowed_address`); TEMP §8 audit risolto |
| 2026-09-15 | § 5.0 — outbox e spunte unificate; worker = solo erogazione (internal vs Gotham); modulo spunte unificato |
| 2026-09-15 | § 4.0 — wire Gotham solo su `im_server_id`; `publicBaseUrl` fuori dal protocollo (solo client web) |
| 2026-09-15 | § 4.2 — API profilo pubblico (`/users/{username}/profile`, `/profiles` batch); discovery con path |
| 2026-09-15 | § 3.0 — wire: `from_user`/`to_user` bare; istanza da firma + Host; `GothamSignedEvent`; READ/REACTION simmetrici |
| 2026-09-15 | § 5.2 — REACTION inbound: `reactor_address` (no FK profilo; allinea a no-shadow) |
| 2026-09-15 | § 3.3 — media: `media_fetch_url` wire; ingest locale; internal = copia server-side |
| 2026-09-13 | § 9 — gruppi **in scope** federazione (correzione: non solo locale) |
| 2026-09-13 | § 6, § 9.1 — erogazione gruppo→membro allineata a pipeline `deliver` standard (PR #284); due gambe; `erogate_group_message` orchestratore |
| 2026-09-24 | § 11 — review modello: decisioni chiuse #1–#6; domande aperte non esaustive (review #7+, gap codice/spec) |
