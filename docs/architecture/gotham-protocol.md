# Gotham — protocollo federazione Alfred

**Ultima revisione:** 2026-09-05  
**Stato:** `documented` — wire contract definito; runtime non implementato (bridge stub)  
**Audience:** AI / implementazione bridge e gateway

**SSOT wire:** [gotham.proto](../specs/contracts/gotham.proto)  
**SSOT piattaforma (mailbox, outbox, id):** [mailbox-inbox-outbox-spec.md](./mailbox-inbox-outbox-spec.md)  
**SSOT indice:** [SSOT.md](../SSOT.md)

Gotham è il protocollo di federazione **nativo** tra istanze Alfred. Sostituisce XMPP/Matrix come target di progetto per il recapito server-to-server su Alfred.

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
| **Backend istanza** | Supabase (outbox, worker `alfred_delivery`) — **no Python** nel path produzione |
| **Bridge** | Stateless — traduce Gotham ↔ outbox Alfred; vedi [bridge-stateless.md](../decisions/bridge-stateless.md) |

Il client Flutter **non** parla Gotham direttamente: parla sempre con la propria piattaforma (RPC Supabase). Il bridge è l’unico emittente/ricevitore Gotham.

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

Il bridge, in caso di retry, rimanda lo **stesso POST** con gli **stessi identificativi di dominio**:

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

### 2.5 `messages.external_id` (DB Alfred)

Colonna DB per id percepiti da **protocolli esterni legacy** (XMPP `id`, Matrix `event_id`). **Non** fa parte del contratto Gotham nativo. Il bridge legacy può usarla; Gotham usa direttamente `logical_message_id`, `read_receipt_id`, `reaction_fact_id`.

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
  media_url?            // URL condiviso tra copie (stesso blob storage)
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

**Perché `LOCATION` è un `EventKind` separato:** sul wire la posizione ha payload dedicato (lat/lng). In DB Alfred `message_content_type` include ancora `location` per storage interno; il bridge mappa `EventKind.LOCATION` → `content_type = location` in ingest. Non usare `MessagePayload` con `content_type = location`.

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
| `public_keys` | Chiavi per firma/verifica envelope (futuro; può essere vuoto in MVP) |

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
| `5xx` | Errore temporaneo — il bridge può ritentare con **gli stessi id** |

**Non** esiste body di ack strutturato: read e reaction sono **eventi separati**, non embedded nell’ack del MESSAGE.

**Enum proto3:** `EVENT_KIND_UNSPECIFIED` e `REACTION_KIND_UNSPECIFIED` esistono solo per compatibilità protobuf. Sul wire **non** vanno usati; il peer rifiuta envelope con kind non riconosciuto.

### 4.3 Indirizzi

Formato: `username@server` dove `server` identifica l’istanza Alfred peer (es. dominio Fly dell’istanza).

Vedi [address-based-messaging.md](../decisions/address-based-messaging.md).

---

## 5. Mapping Gotham ↔ piattaforma Alfred

Stesso bus **outbox** per internal e federato; differisce solo il consumer in fondo.

| Gotham `kind` | `outbox.event_kind` | Payload outbox (campi chiave) |
|---------------|---------------------|-------------------------------|
| MESSAGE / LOCATION | `deliver` | `logical_message_id`, `sender_id`, `recipient_profile_id`, snapshot contenuto |
| READ | `read_receipt` | `logical_message_id`, `read_receipt_id`, `reader_id`, `sender_profile_id` |
| REACTION | `reaction_fact` | `logical_message_id`, `reactor_id`, `kind`, `emoji`; completamento con `reaction_fact_id` |

### 5.1 Outbound (istanza mittente → peer)

```text
1. RPC account (es. send_message_to_profile)
     → INSERT copia mittente (logical_message_id mintato)
     → INSERT outbox (event_kind=deliver, protocol=gotham, status=queued)

2. Bridge claim outbox (protocol != internal)
     → costruisce GothamEnvelope
     → POST /gotham/v1/events verso to_address

3. HTTP 2xx dal peer
     → bridge aggiorna delivered_at sulla copia mittente
     → outbox completed
```

Su **internal** oggi il worker gira sincrono nella stessa transazione RPC (`protocol = internal`). Per federato il passo 2 è **async** (outbox resta `queued` fino al bridge).

| `outbox.protocol` | Consumer | Quando |
|-------------------|----------|--------|
| `internal` | `alfred_delivery.process_outbox` (sincrono in transazione RPC) | Oggi |
| `gotham` | Bridge worker (claim async) | Da implementare |

**Debito implementativo — `outbox.message_id`:** colonna FK con significato diverso per `event_kind` (ancora mittente, lettore, destinatario push, …). Vedi [schema.md](../specs/contracts/schema.md) § outbox. Il bridge Gotham deve leggere gli id dal **payload**, non inferirli da `message_id`.

### 5.2 Inbound (peer → istanza destinatario)

```text
1. Gateway Fly riceve POST /gotham/v1/events

2. Bridge valida envelope, risolve indirizzi → profile_id

3. Gate reception (allow list destinatario)
     SE consentito:
       MESSAGE → alfred_delivery.materialize_inbound_sender_message(...)
                 (logical_message_id dal server mittente remoto — non rigenerare)
       READ    → worker propaga read_at + read_receipt_id sulla copia mittente locale
       REACTION→ worker INSERT message_reaction_facts

4. HTTP 2xx
```

Vedi RPC `materialize_inbound_sender_message` in [rpc.md](../specs/contracts/rpc.md).

### 5.3 Spunte

| Livello UI | Significato | Gotham / piattaforma |
|------------|-------------|----------------------|
| ✓ | Accettato server mittente | Copia mittente creata |
| ✓✓ grigie | Nella fonte di verità destinatario | HTTP 2xx su MESSAGE / `delivered_at` |
| ✓✓ blu | Destinatario ha letto | Evento READ separato con `read_receipt_id` |

Semantica UI: [server-as-reception.md](../decisions/server-as-reception.md).

---

## 6. Piattaforma Alfred — stato implementazione (`main`)

Prerequisiti piattaforma per Gotham (implementati):

| Requisito | PR / migrazione |
|-----------|-----------------|
| `logical_message_id` mintato dal server mittente, replicato sul destinatario | #264 — `20260905000000_sender_global_message_id.sql` |
| Inbound materialize con id remoto | `materialize_inbound_sender_message` |
| Reaction via outbox | #265 — `20260905120000_reaction_fact_outbox.sql` |
| `read_receipt_id` mint lettore → replica mittente | #266 — `20260905140000_read_receipt_id.sql` |

Bus outbox `event_kind` attivi: `deliver`, `read_receipt`, `reaction_fact`, `group_erogate`, `push_notify`.

`push_notify` è **solo internal**: accodato dal worker dopo recapito locale riuscito ([SYS-PUSH](../specs/promises/system/SYS-PUSH.md)). **Non** compare mai sul wire Gotham.

**Enum `contact_protocol`:** i flussi federati assumono `outbox.protocol = gotham`. Su `main` l’enum Postgres ha ancora solo `internal`, `xmpp`, `matrix` — serve migrazione che aggiunga `gotham` prima di abilitare send federato.

---

## 7. Componenti runtime (da implementare)

| Componente | Stato | Ruolo |
|------------|-------|-------|
| **Gateway Fly HTTP/3** | ❌ | Termina QUIC; espone `/.well-known/gotham` e `/gotham/v1/events` |
| **Bridge worker** | ❌ stub | Claim outbox `protocol = gotham`; traduce ↔ Protobuf; chiama Supabase |
| **Send path async** | ❌ | `protocol != internal` → outbox `queued` **senza** `process_outbox` sincrono |
| **Spec in repo** | ✅ | Questo file + `gotham.proto` |

I bridge Python esistenti (`bridge-xmpp`, `bridge-matrix`) espongono solo `GET /health` — non sono il consumer Gotham.

---

## 8. Architettura fisica

```text
┌─────────────┐     RPC      ┌──────────────────┐
│ Flutter web │ ───────────► │ Supabase (istanza)│
└─────────────┘              │  outbox + worker  │
                             └────────┬─────────┘
                                      │ claim (federato)
                             ┌────────▼─────────┐
                             │ Bridge (Fly)      │
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
- Il bridge è **stateless**: stato autorevole solo su Postgres (outbox, messages, reaction facts).

---

## 9. Scope MVP e fuori scope

| In scope MVP Gotham | Fuori scope |
|---------------------|-------------|
| Messaggistica 1:1 (`MESSAGE`, `LOCATION`) | Gruppi federati |
| READ, REACTION come eventi separati | Multi-account sul wire |
| HTTP/3 + Protobuf + discovery | E2E encryption |
| Ack MESSAGE = solo HTTP status | `push_notify` sul wire |
| | Body di ack strutturato |

I gruppi restano **internal** sulla stessa istanza (`group_erogate`, `broadcast_message_to_allowlist`).

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
| [bridge-stateless.md](../decisions/bridge-stateless.md) | Bridge senza stato business |
| [domain/federation/](../domain/federation/) | Contesto DDD federation |
| [SYS-DELIVERY](../specs/promises/system/SYS-DELIVERY.md) | Promesse worker outbox |
| [full-stack.md](./full-stack.md) | Limitazioni attuali stack |

---

## Changelog documento

| Data | Modifica |
|------|----------|
| 2026-09-05 | Prima stesura — envelope senza `event_id` / `external_id`; id federativi nominati; mapping outbox |
| 2026-09-05 | Chiarimenti: MESSAGE = solo `logical_message_id`; LOCATION separato; `push_notify` internal-only; debito `contact_protocol` / `outbox.message_id` |
