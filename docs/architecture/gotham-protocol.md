# Gotham — protocollo federazione Alfred

**Ultima revisione:** 2026-09-09  
**Stato:** `documented` — wire contract definito; runtime non implementato  
**Audience:** AI / implementazione gateway e worker Gotham

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
| **Discovery** | `GET /.well-known/gotham` → `GothamDiscovery` |
| **Invio eventi** | `POST /gotham/v1/events` — body = `GothamEnvelope` serializzato |
| **Ack consegna** | Solo **codice HTTP** (2xx = accettato dal peer) |
| **Backend istanza** | Supabase (outbox, worker `alfred_delivery`) |
| **Federazione** | Gateway Fly HTTP/3 + worker Gotham (da implementare) |

Il client Flutter **non** parla Gotham direttamente: parla sempre con la propria piattaforma (RPC Supabase). Solo il worker Gotham emette/riceve sul wire.

---

## 2. Identificatori

### 2.1 Regola generale

Ogni fatto ha **un nome preciso**. Non esistono campi generici `event_id` o `external_id` sull’envelope Gotham.

| Fatto | Campo id | Chi lo assegna | Quando |
|-------|----------|----------------|--------|
| **Messaggio** (testo, media, location) | `logical_message_id` | Server **mittente** | Accettazione invio (`send_message_to_profile`) |
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

### 4.1 Discovery

```http
GET /.well-known/gotham HTTP/3
Accept: application/x-protobuf
```

Risposta `200`: body `GothamDiscovery` (protobuf).

Campi minimi:

| Campo | Contenuto |
|-------|-----------|
| `version` | Versione protocollo (es. `"1"`) |
| `public_keys` | Chiavi per firma/verifica envelope (futuro; può essere vuoto finché la firma non è attiva) |

### 4.2 Invio evento

```http
POST /gotham/v1/events HTTP/3
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

### 4.3 Indirizzi

Formato: `username@server` dove `server` identifica l’istanza Alfred peer (es. dominio Fly dell’istanza).

| Campo envelope | Ruolo |
|----------------|--------|
| `from_address` | Mittente federato (`mario@arkham-im.fly.dev`) |
| `to_address` | Destinatario federato (`paolo@blackgate-im.fly.dev`) |

**Normalizzazione (vincolante):** confronto case-insensitive su username e server; formato canonico in DB e su wire = `lower(username)@lower(server)` (server = `im_server_id` dell’istanza peer).

Vedi [address-based-messaging.md](../decisions/address-based-messaging.md).

---

## 5. Mapping Gotham ↔ piattaforma Alfred

Stesso bus **outbox** per recapito locale e federato; differisce solo il consumer in fondo.

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
     → INSERT copia mittente (logical_message_id mintato; peer_address = p_peer_address)
     → INSERT outbox (event_kind=deliver, status=queued)

2. Stessa istanza (server di p_peer_address = im_server_id locale):
     worker `alfred_delivery.process_outbox` sincrono
   Altra istanza:
     outbox resta `queued` → worker Gotham → POST /gotham/v1/events

3. HTTP 2xx dal peer (federato)
     → delivered_at sulla copia mittente
     → outbox completed
```

Routing **senza colonna protocol**: il server in `peer_address` (`user@server`) determina recapito locale vs federato.

### 5.2 Inbound (peer → istanza destinatario)

```text
1. Gateway Fly riceve POST /gotham/v1/events

2. Worker federativo valida envelope (kind, indirizzi normalizzati, id dedup)

3. Gate reception (allow list destinatario) — § 5.4
     confronto envelope.from_address con allowed_external_address del destinatario

4. SE consentito:
       MESSAGE / LOCATION → materialize copia destinatario
         (logical_message_id remoto; peer_address = from_address; author_address = from_address)
       READ    → propaga read_at + read_receipt_id sulla copia mittente locale (per λ)
       REACTION→ INSERT message_reaction_facts

5. HTTP 2xx (anche su rifiuto silenzioso allow list — evento processato, nessuna copia)
```

Materializzazione inbound federata: variante **indirizzo-based** su `peer_address` / `author_address` — vedi § 5.4.

### 5.3 Spunte

| Livello UI | Significato | Gotham / piattaforma |
|------------|-------------|----------------------|
| ✓ | Accettato server mittente | Copia mittente creata |
| ✓✓ grigie | Nella fonte di verità destinatario | HTTP 2xx su MESSAGE / `delivered_at` |
| ✓✓ blu | Destinatario ha letto | Evento READ separato con `read_receipt_id` |

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
materialize_inbound_federated_message(
  p_recipient_profile_id uuid,      -- auth.uid() / destinatario locale
  p_from_address text,              -- envelope.from_address normalizzato
  p_logical_message_id uuid,        -- dal server mittente remoto — mai rigenerare
  … snapshot contenuto …
) → messages
```

Riga archivio destinatario:

| Campo | Valore |
|-------|--------|
| `archive_user_id` | destinatario locale |
| `peer_address` | `p_from_address` |
| `author_address` | `p_from_address` |
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
| `materialize_inbound_federated_message` | Inbound con `peer_address` / `author_address` |
| Consumer outbox federato + Gotham ingress (HTTP/3) | § 7 |

Bus outbox `event_kind` attivi: `deliver`, `read_receipt`, `reaction_fact`, `group_erogate`, `push_notify`.

`push_notify` è **solo locale** (piattaforma): accodato dal worker dopo recapito locale riuscito ([SYS-PUSH](../specs/promises/system/SYS-PUSH.md)). **Non** compare mai sul wire federato.

**Nessun campo `protocol`:** il routing è implicito — server in `peer_address` / `allowed_address` / `contacts.address` determina locale vs federato.

---

## 7. Componenti runtime (da implementare)

| Componente | Stato | Ruolo |
|------------|-------|-------|
| **Gateway Fly HTTP/3** | ❌ | Termina QUIC; espone `/.well-known/gotham` e `/gotham/v1/events` |
| **Gotham worker** | ❌ | Claim outbox federato; traduce ↔ Protobuf; materialize inbound |
| **Spec in repo** | ✅ | Questo file + `gotham.proto` |

Il gateway Python in `client/deploy/gateway/` serve solo la shell PWA (branding dinamico) — **non** è il gateway Gotham di questa sezione.

---

## 8. Architettura fisica

```text
┌─────────────┐     RPC      ┌──────────────────┐
│ Flutter web │ ───────────► │ Supabase (istanza)│
└─────────────┘              │  outbox + worker  │
                             └────────┬─────────┘
                                      │ claim (federato)
                             ┌────────▼─────────┐
                             │ Worker federativo │
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
- Il worker Gotham è **stateless**: stato autorevole solo su Postgres (outbox, messages, reaction facts).

---

## 9. Scope e fuori scope

| In scope Gotham | Fuori scope |
|-----------------|-------------|
| Messaggistica 1:1 testo + `LOCATION` | Gruppi federati |
| `MESSAGE` con media (dopo ingest locale destinatario — vedi [mailbox-inbox-outbox-spec.md](./mailbox-inbox-outbox-spec.md) § Media) | Media federati senza ingest |
| READ, REACTION come eventi separati | Multi-account sul wire |
| HTTP/3 + Protobuf + discovery | E2E encryption |
| Ack MESSAGE = solo HTTP status | `push_notify` sul wire |
| | Body di ack strutturato |

I gruppi restano **locale** (stessa istanza) — `group_erogate`, `broadcast_message_to_allowlist`.

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
