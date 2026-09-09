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
| MESSAGE / LOCATION | `deliver` | `logical_message_id`, snapshot contenuto; **locale:** `recipient_profile_id`; **federato:** `peer_external_address` |
| READ | `read_receipt` | `logical_message_id`, `read_receipt_id`; **locale:** `reader_id`, `sender_profile_id`; **federato:** indirizzi wire |
| REACTION | `reaction_fact` | `logical_message_id`, `reaction_fact_id`, `kind`, `emoji`; **federato:** indirizzi wire |

### 5.1 Outbound (istanza mittente → peer)

```text
1. RPC account
     Locale:  send_message_to_profile(recipient_profile_id, …)
     Federato: send_message_to_external_address(peer_external_address, …)  ← con Gotham
     → gate outbound allow list (§ 5.4)
     → INSERT copia mittente (logical_message_id mintato; peer_profile_id O peer_external_address)
     → INSERT outbox (event_kind=deliver, status=queued)

2. Stessa istanza: worker `alfred_delivery.process_outbox` sincrono
   Altra istanza: outbox resta `queued` → worker Gotham → POST /gotham/v1/events

3. HTTP 2xx dal peer (federato)
     → delivered_at sulla copia mittente
     → outbox completed
```

Routing **senza colonna protocol**: `peer_profile_id` valorizzato = recapito locale; `peer_external_address` = federato.

### 5.2 Inbound (peer → istanza destinatario)

```text
1. Gateway Fly riceve POST /gotham/v1/events

2. Worker federativo valida envelope (kind, indirizzi normalizzati, id dedup)

3. Gate reception (allow list destinatario) — § 5.4
     confronto envelope.from_address con allowed_external_address del destinatario

4. SE consentito:
       MESSAGE / LOCATION → materialize copia destinatario
         (logical_message_id remoto; peer_external_address = from_address; peer_profile_id null)
       READ    → propaga read_at + read_receipt_id sulla copia mittente locale (per λ)
       REACTION→ INSERT message_reaction_facts

5. HTTP 2xx (anche su rifiuto silenzioso allow list — evento processato, nessuna copia)
```

L’helper attuale `materialize_inbound_sender_message` (profile_id locale mittente) **non** è sufficiente per Gotham: va esteso o affiancato da una variante **indirizzo-based** — vedi § 5.4.

### 5.3 Spunte

| Livello UI | Significato | Gotham / piattaforma |
|------------|-------------|----------------------|
| ✓ | Accettato server mittente | Copia mittente creata |
| ✓✓ grigie | Nella fonte di verità destinatario | HTTP 2xx su MESSAGE / `delivered_at` |
| ✓✓ blu | Destinatario ha letto | Evento READ separato con `read_receipt_id` |

Semantica UI: [server-as-reception.md](../decisions/server-as-reception.md).

### 5.4 Reception — allow list locale ed esterna (con Gotham)

Stessa semantica [SYS-RECEPTION](../specs/promises/system/SYS-RECEPTION.md) del recapito locale, estesa agli indirizzi federati. La lista **non** è solo profili locali: ogni titolare archivio può consentire **utenti Alfred sulla stessa istanza** e **indirizzi `user@server` su altre istanze**. Stesso modello della rubrica (`contacts`: `linked_profile_id` **oppure** `external_address`).

**Implementazione:** introdotta **insieme a Gotham** (oggi `reception_allowlist` ha solo `allowed_profile_id` — vedi § 6).

#### Schema `reception_allowlist` (target)

| Colonna | Uso |
|---------|-----|
| `archive_user_id` | Titolare archivio che filtra (invariato) |
| `allowed_profile_id` | Peer **stessa istanza** (`profiles.id`) |
| `allowed_external_address` | Peer **federato** (`username@im_server_id`) |

**Vincoli:**

- Esattamente **uno** tra `allowed_profile_id` e `allowed_external_address` valorizzato (mutua esclusione, come `contacts`).
- `allowed_external_address` normalizzato: `lower(username)@lower(server)`.
- UNIQUE `(archive_user_id, allowed_profile_id)` dove `allowed_profile_id IS NOT NULL`.
- UNIQUE `(archive_user_id, lower(allowed_external_address))` dove `allowed_external_address IS NOT NULL`.
- `allowed_profile_id <> archive_user_id` se valorizzato.

#### Gate inbound (destinatario riceve da peer remoto)

Condizione recapito federato (equivalente a SYS-RECEPTION-006 per profili locali):

```text
EXISTS reception_allowlist
  WHERE archive_user_id = destinatario_locale
    AND allowed_external_address = normalize(envelope.from_address)
```

- Lista vuota → nessun `from_address` passa → nessuna copia destinatario (silenzio verso mittente remoto).
- Su rifiuto: **nessuna** INSERT copia destinatario; risposta HTTP **2xx** al peer mittente (evento processato / dedup — non leak del filtro).
- **Non** usare `contacts` come proxy della allow list (SYS-RECEPTION-022).

#### Gate outbound (mittente invia verso peer remoto)

Prima di INSERT copia mittente federata:

```text
EXISTS reception_allowlist
  WHERE archive_user_id = mittente_locale
    AND allowed_external_address = normalize(destinazione)
```

Su violazione: `raise exception 'recipient not in reception allowlist'` — **nessuna** copia mittente (come outbound locale, SYS-RECEPTION-031).

#### RPC invio federato (piattaforma, con Gotham)

Nuovo punto di invio account (nome indicativo):

```sql
send_message_to_external_address(
  p_peer_external_address text,
  … stessi campi contenuto di send_message_to_profile …
) → messages
```

Semantica:

1. Normalizza `p_peer_external_address`; rifiuta se `server` = `im_server_id` locale (usa flusso locale).
2. Gate outbound § sopra.
3. INSERT copia mittente: `peer_external_address` valorizzato, `peer_profile_id` null, `logical_message_id` mintato.
4. INSERT `outbox` (`event_kind = deliver`, `status = queued`, payload con `peer_external_address`).
5. **Non** chiama `process_outbox` sincrono — il consumer Gotham claima la riga.

Il client smette di rifiutare il compose verso `user@server` quando Gotham è attivo ([SYS-MAILBOX-030](../specs/promises/system/SYS-MAILBOX.md) revocato per federazione).

#### Materializzazione inbound (copia destinatario)

Nuova RPC/helper (o estensione di `materialize_inbound_sender_message`):

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
| `peer_external_address` | `p_from_address` |
| `peer_profile_id` | null |
| `logical_message_id` | dal mittente remoto |
| `author_external_address` | `p_from_address` (nuova colonna — vedi sotto) |
| `author_id` | null su ingresso federato |

**Autore senza profilo locale:** il mittente remoto non ha `profiles.id` sulla istanza destinataria. Estensione `messages`:

- `author_external_address text nullable` — valorizzato su messaggi in entrata federati.
- CHECK: messaggio in entrata ha `author_id` **oppure** `author_external_address` (uno dei due).
- UI / inbox: display da rubrica (`contacts.external_address`) o da `from_address`; nessun profilo shadow obbligatorio in `profiles`.

#### UI allow list (riferimento superficie)

Allineata a [SURF-CONTACTS-007](../specs/surfaces/SURF-CONTACTS.md):

- Aggiunta **locale:** `search_profiles` → `allowed_profile_id`.
- Aggiunta **federata:** form `user@server` + etichetta → `allowed_external_address`.
- Lista mostra nome / `@username` per locali e indirizzo completo per federati.

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
| `reception_allowlist.allowed_external_address` | § 5.4 — allow list locale + federata |
| `send_message_to_external_address` | Invio verso `peer_external_address` + outbox federato |
| `materialize_inbound_federated_message` + `messages.author_external_address` | Inbound senza `profiles.id` mittente |
| Consumer outbox federato + Gotham ingress (HTTP/3) | § 7 |

Bus outbox `event_kind` attivi: `deliver`, `read_receipt`, `reaction_fact`, `group_erogate`, `push_notify`.

`push_notify` è **solo locale** (piattaforma): accodato dal worker dopo recapito locale riuscito ([SYS-PUSH](../specs/promises/system/SYS-PUSH.md)). **Non** compare mai sul wire federato.

**Nessun campo `protocol`:** il routing è implicito — `linked_profile_id` / `peer_profile_id` per contatti locali, `external_address` / `peer_external_address` per indirizzi federati.

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
