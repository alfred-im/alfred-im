# Gotham — protocollo federazione Alfred

**Ultima revisione:** 2026-09-15  
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

### 3.1 Root comune

```text
GothamEnvelope
  kind                         EventKind
  from_address                 string   (mittente federato, es. mario@alfred.example)
  to_address                   string   (destinatario federato)
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
  media_url?            // URL sorgente lato mittente — il peer deve ingest locale (vedi mailbox § Media)
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

---

## 4. HTTP

### 4.0 Host federativo — `im_server_id` (vincolante)

Il wire Gotham **non** usa `publicBaseUrl` (hosting del client Flutter/PWA). Tutte le interazioni del protocollo federativo avvengono sull’host **`im_server_id`** dell’istanza — lo stesso dominio che compare dopo la `@` negli indirizzi IM (`mario@im.example`).

| Config | Ruolo | Sul wire Gotham? |
|--------|--------|------------------|
| `im_server_id` | Identità istanza IM; parte `@server` negli indirizzi | **Sì** — host di discovery ed eventi |
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
| `public_keys` | Chiavi per firma/verifica envelope (futuro; può essere vuoto finché la firma non è attiva) |
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
| Batch | `POST /gotham/v1/profiles` — stessi campi di `get_profiles`; indirizzi il cui `@server` ≠ host → `4xx` |
| Assente | Utente inesistente su quell’istanza → `404` (singolo) o omesso nel batch |
| Avatar / cover | URL possono puntare allo Storage **dell’istanza origine** — vedi [mailbox-inbox-outbox-spec.md](./mailbox-inbox-outbox-spec.md) § Media |

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
2. Per ogni istanza peer: `POST …/gotham/v1/profiles` (o GET singoli se batch non disponibile).
3. Merge nel result set RPC; indirizzo senza risposta → riga con solo `address` (fallback grezzo).

Il **client Flutter non chiama Gotham** — solo la piattaforma (implementazione `get_profiles` / gateway).

### 4.3 Invio evento (fatti messaggistica)

```http
POST https://{im_server_id}/gotham/v1/events HTTP/3
Content-Type: application/x-protobuf

<body: GothamEnvelope>
```

| Codice | Significato |
|--------|-------------|
| `2xx` | Evento accettato e processato (o già visto — dedup idempotente) |
| `4xx` | Rifiuto permanente (malformato, indirizzo sconosciuto, …) |
| `5xx` | Errore temporaneo — il worker può ritentare con **gli stessi id** |

**Non** esiste body di ack strutturato: read e reaction sono **eventi separati**, non embedded nell’ack del MESSAGE.

**Enum proto3:** `EVENT_KIND_UNSPECIFIED` e `REACTION_KIND_UNSPECIFIED` esistono solo per compatibilità protobuf. Sul wire **non** vanno usati; il peer rifiuta envelope con kind non riconosciuto.

### 4.4 Indirizzi

Formato: `username@server` dove `server` identifica l’istanza Alfred peer (es. dominio Fly dell’istanza).

| Campo envelope | Ruolo |
|----------------|--------|
| `from_address` | Mittente federato (`mario@arkham-im.fly.dev`) |
| `to_address` | Destinatario federato (`paolo@blackgate-im.fly.dev`) |

**Normalizzazione (vincolante):** confronto case-insensitive su username e server; formato canonico in DB e su wire = `lower(username)@lower(server)` (server = `im_server_id` dell’istanza peer).

Vedi [address-based-messaging.md](../decisions/address-based-messaging.md).

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
| READ | `read_receipt` | `logical_message_id`, `read_receipt_id`; indirizzi wire (`reader_address`, `sender_address`) |
| REACTION | `reaction_fact` | `logical_message_id`, `reaction_fact_id`, `kind`, `emoji`; indirizzi wire |

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

2. Worker Gotham (ingress) valida envelope (kind, indirizzi normalizzati, id dedup)

3. Gate reception (allow list destinatario) — § 5.4
     confronto envelope.from_address con allowed_address del destinatario

4. SE consentito:
       MESSAGE / LOCATION → materialize copia destinatario
         (logical_message_id remoto; peer_address = from_address; author_address = from_address)
       READ    → propaga read_at + read_receipt_id sulla copia mittente locale (per λ)
       REACTION→ INSERT message_reaction_facts

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
    AND allowed_address = normalize(envelope.from_address)
```

- Lista vuota → nessun `from_address` passa → nessuna copia destinatario (silenzio verso mittente remoto).
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
  p_sender_address text,            -- envelope.from_address normalizzato
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

Envelope include sempre `from_address` / `to_address`. Il gate inbound per eventi che **non** creano messaggio usa la stessa allow list su `from_address` prima di propagare segnali sulla copia mittente locale.

---

## 6. Piattaforma Alfred — stato implementazione (`main`)

Prerequisiti piattaforma per Gotham (implementati):

| Requisito | PR / migrazione |
|-----------|-----------------|
| `logical_message_id` mintato dal server mittente, replicato sul destinatario | #264 — `20260905000000_sender_global_message_id.sql` |
| Inbound materialize con id remoto | `materialize_inbound_sender_message` |
| Reaction via outbox | #265 — `20260905120000_reaction_fact_outbox.sql` |
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
| Profilo pubblico remoto (`PublicProfile` / batch) | Media federati senza ingest |
| **Gruppi** — identità `@username` / `@username@server`; recapito umano→gruppo; erogazione verso partecipanti su allow list (locali e federati, stesso modello `allowed_address`) | Multi-account sul wire |
| `MESSAGE` con media (dopo ingest locale destinatario — vedi [mailbox-inbox-outbox-spec.md](./mailbox-inbox-outbox-spec.md) § Media) | E2E encryption |
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
| Firma envelope con `public_keys` da discovery | Futuro — campo presente in `GothamDiscovery` |
| Gate reception su inbound | Obbligatorio — [SYS-RECEPTION](../specs/promises/system/SYS-RECEPTION.md) |

---

## 11. Riferimenti

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
| 2026-09-09 | `media_url` wire: ingest locale destinatario obbligatorio — vedi mailbox § Media |
| 2026-09-09 | § 5.4 — `reception_allowlist` locale + esterna; RPC invio/materialize federato; gate su `from_address` |
| 2026-09-13 | § 5.4 — modello address-based unificato (`peer_address`, `author_address`, `allowed_address`); TEMP §8 audit risolto |
| 2026-09-15 | § 5.0 — outbox e spunte unificate; worker = solo erogazione (internal vs Gotham); modulo spunte unificato |
| 2026-09-15 | § 4.0 — wire Gotham solo su `im_server_id`; `publicBaseUrl` fuori dal protocollo (solo client web) |
| 2026-09-15 | § 4.2 — API profilo pubblico (`/users/{username}/profile`, `/profiles` batch); discovery con path |
| 2026-09-13 | § 9 — gruppi **in scope** federazione (correzione: non solo locale) |
| 2026-09-13 | § 6, § 9.1 — erogazione gruppo→membro allineata a pipeline `deliver` standard (PR #284); due gambe; `erogate_group_message` orchestratore |
