# TEMP — Deriva chiave conversazione: indirizzo vs `profileId`

**Stato:** bozza temporanea — da eliminare dopo promozione in SDD `approved`  
**Revisione:** 2026-09-13 (settima passata — catalogo §9.1: 52 domande/risposte)  
**Audience:** revisione modello / SDD / implementazione federazione  
**Non è SSOT** — vedi `docs/SSOT.md`. Contenuto da distillare in dominio, promesse e contratti.

**Legenda sezioni**

| Sezione | Contenuto |
|---------|-----------|
| §7 | Decisioni di modello **chiuse** (review 2026-09-12) — da promuovere in SDD |
| §8 | Audit documentazione — tensioni verificate |
| §9 | Domande aperte — **nessuna**; catalogo completo **§9.1** (52 Q→R) |
| §10 | Lavoro da fare — formalizzazione SDD + implementazione |

---

## 1. Sintesi

**Direttiva vincolante** (architettura + ADR): conversazione 1:1 = `(mio account, indirizzo controparte)` — `username` o `user@server`. Nessuna tipologia «chat locale» vs «chat federata» in UI, account, inbox, allow list o RPC.

**Deriva:** implementazione e promesse `implemented` hanno cristallizzato la chiave su `peer_profile_id` (UUID). Con ogni peer su profilo locale funzionava; la federazione Arkham ↔ Blackgate espone il disallineamento.

**Correzione:** chiave canonica = **`peer_address`** (lowercase); **`author_address`** sulla copia mittente = identità che fa fede nella comunicazione (§7.5b). **Tutti gli account** (umani e gruppi). Presentazione = **`get_profiles(addresses[])`** (batch, profilo pubblico sempre). Push = **`peerAddress`** (no dual-read). Gotham = solo trasporto (+ amend doc §5.4 nello stesso workstream). Ordine: SDD → reception API → client → allow list → worker Gotham. **§9 vuoto** — modello pronto per distillazione SDD.

### 1.1 Scope workstream

Messaggistica 1:1, allow list, rubrica (`contacts`), gruppi, push, link, mention, `gotham-protocol.md` / `gotham.proto` (modello prodotto §5.4) — stesso vincolo §7.1 (solo stringa indirizzo).

### 1.2 Clean break (implementazione)

| Regola | Dettaglio |
|--------|-----------|
| **Rimuovere** | Colonne/RPC/tipi/promesse del modello UUID-split (`peer_profile_id`, `peer_external_address`, `linked_profile_id`, `allowed_profile_id`, `author_external_address`, overload UUID, alias `*_external_*`, dual-read push) |
| **Vietato** | `@deprecated`, campi paralleli, doppio percorso UUID **o** indirizzo, migrazione/backfill conversazioni |
| **Dati** | Wipe `messages` e righe derivate (allow list, contacts, outbox collegate); **account restano** (`auth.users`, `profiles`) — §7.15 |
| **Doc** | Amend sostitutivi; Gotham §5.4 allineato a `*_address` unificato |

Il delivery può risolvere username → profilo **in transazione**; l'UUID non è chiave conversazione né contratto client.

---

## 2. Direttiva originale (invariata)

| Fonte | Regola |
|-------|--------|
| `mailbox-inbox-outbox-spec.md` § Identità chat | `(io, indirizzo controparte)`; niente `thread_id` client |
| `no-internal-external-chat-distinction.md` | Vietata tipologia chat locale/federata; routing solo in delivery |
| `address-based-messaging.md` | Si scrive a un indirizzo; rubrica isolata; inbox on-read |

---

## 3. Deriva attuale (codice + SDD `implemented`)

### 3.1 Promesse

| Fonte | Problema |
|-------|----------|
| `PROM-CHAT-PEER-KEY` | `-001` (indirizzo) vs `-002`/`-003` (profileId) — contraddittorio |
| `SYS-MAILBOX` | `-034`–`-038`, `-047`: inbox/storico/lettura/unread su UUID |
| `SYS-MAILBOX-030` | compose federato `unsupported` (v1; da revocare con federazione) |
| `SYS-RECEPTION` | gate su `allowed_profile_id` UUID |
| `SYS-CONTACTS` | snapshot nome/avatar; split `linked_profile_id` / `external_address` |
| `PROM-SHAREABLE-LINK-002` | «equivalenza forme» — da riconciliare con §7.2 (vedi §7.14) |

### 3.2 Schema e RPC

- `messages`: split `peer_profile_id` + `peer_external_address`; `author_id NOT NULL`.
- `list_peer_messages(uuid)`, `mark_peer_read(uuid)` — nessun parametro indirizzo.
- `list_inbox()`: SQL filtra `peer_profile_id IS NOT NULL` — righe solo `peer_external_address` **escluse** (`contracts/rpc.md` documenta OR non implementato).
- Nessun `get_profiles(addresses[])` — solo batch UUID (`ProfileService.fetchSummariesByIds`).

### 3.3 Client

- `ChatPeer` richiede `ProfileSummary.id`.
- Navigation, scope, realtime, push: chiave `peerProfileId` (UUID).
- `compose_service`: `user@server` → unsupported.
- `shareable_link_machine`: server remoto → `invalid`; lookup `find_profile_by_username` (UUID).

### 3.4 Rubrica e profilo

| Aspetto | Stato attuale | Modello target (§7) |
|---------|---------------|---------------------|
| `contacts` locale | `linked_profile_id` + snapshot | Solo `address` lowercase |
| `contacts` federato | `external_address` + `display_name` obbligatorio | Solo `address` |
| Dati profilo in UI | Join `profiles` / denormalizzazione inbox | `get_profiles(addresses[])` batch |
| Overlay peer remoto | Assente | Stesso `get_profiles` per qualsiasi indirizzo |

---

## 4. Perché la federazione espone la deriva (non la crea)

Prima: ogni peer aveva `profiles.id` locale; UUID come chiave runtime era trasparente.

Dopo: `mario@blackgate-im.fly.dev` non ha `profiles.id` su Arkham → inbox, chat, lettura, push, scope, overlay non funzionano. Wire Gotham e colonne federate esistono; modello account/client no.

---

## 5. Sintomi → causa radice

| Sintomo | Causa |
|---------|-------|
| Compose `user@server` → unsupported | Chiave runtime = profilo locale |
| Inbox senza chat federate | `list_inbox` solo su `peer_profile_id` |
| Storico/lettura inutilizzabili per federato | RPC solo UUID |
| `ChatPeer` non costruibile per remoto | `ProfileSummary.id` obbligatorio |
| Push / navigation / realtime | Pipeline su `peerProfileId` |
| `#user@other-server` → invalid/404 | Lookup locale; `resolveShareableAddress` rifiuta server remoto |
| Rubrica con nome senza `get_profiles` | Snapshot in `contacts` |
| Inbox N+1 profili | Join `profiles`; manca batch indirizzo |

---

## 6. Cosa **non** è il problema

- Wire Gotham (envelope, dedup, ack HTTP) per messaggi 1:1.
- Outbox unica locale/federata (mailbox § Consegna).
- Gap media ingest, READ/REACTION outbound, errori outbox — correlati, scope distinto (§11).

---

## 7. Decisioni di modello (chiuse — review 2026-09-12 / 2026-09-13)

> Emersero in review documentata in questo TEMP. **Non sono SSOT** finché non in promesse `approved`. §9 **vuoto** — nessuna domanda aperta residua.

### 7.1 Principi

1. Non esiste locale/federato a livello account/UI/inbox/allow list/RPC — solo stringa indirizzo.
2. **Delivery** è l'unico modulo che legge `@server` e sceglie driver (interno vs Gotham).
3. **Gotham** = trasporto cross-server, non tipo di chat.

### 7.2 Forme indirizzo e chiave messaggistica

| Input | Significato |
|-------|-------------|
| `mario` | Stessa istanza (bare username) |
| `mario@arkham-im.fly.dev` | Server esplicito (stessa istanza se `@server` = `im_server_id` locale) |
| `mario@blackgate-im.fly.dev` | Altra istanza |

**Regole (chiave `peer_address` / allow list / inbox):**

- **`mario` ≠ `mario@arkham-im.fly.dev`** — identità, chat e voci allow list **distinte**. «Per ora» nel testo architetturale = **regola valida nel modello corrente**, non voce da rivalutare a ogni revisione.
- Input case insensitive; persistenza **sempre lowercase**.
- Entrambe le forme usabili in compose e allow list.
- Delivery: `@mio_server` → recapito interno **senza** fondere stringhe né unificare chat.

### 7.3 Inbox

Raggruppamento per **indirizzo controparte** per titolare archivio (asimmetrico tra archivi).

Esempio Paolo (Arkham) ↔ Mario (Blackgate): inbox Paolo → `mario@blackgate-im.fly.dev`; inbox Mario → `paolo@arkham-im.fly.dev`.

### 7.4 `author_address` — stessa istanza

| Paolo scrive a | Mario vede mittente come |
|----------------|--------------------------|
| `mario` | `paolo` |
| `mario@arkham-im.fly.dev` | `paolo@arkham-im.fly.dev` |

La forma usata per indirizzare la controparte determina l'identità mittente sul destinatario.

### 7.5 `author_address` — federato (Gotham + §7.4)

| Caso | `author_address` |
|------|------------------|
| Inbound federato (B riceve da A) | Indirizzo completo mittente da envelope (`from_address`) — es. `paolo@arkham-im.fly.dev` |
| Wire Gotham | Sempre `user@server` completo (`gotham-protocol.md` §4.3, §5.2) |

### 7.5b Copia mittente in uscita — regola (chiusa 2026-09-13)

Sulla **copia locale del mittente**, `author_address` è **sempre** l'identità che fa fede in quella comunicazione — allineata a §7.4 e al wire.

| Paolo (Arkham) compone verso | `peer_address` (copia Paolo) | `author_address` (copia Paolo) |
|------------------------------|------------------------------|--------------------------------|
| `mario` (stessa istanza) | `mario` | `paolo` |
| `mario@arkham-im.fly.dev` | `mario@arkham-im.fly.dev` | `paolo@arkham-im.fly.dev` |
| `mario@blackgate-im.fly.dev` | `mario@blackgate-im.fly.dev` | `paolo@arkham-im.fly.dev` |

Scrivendo **all'esterno** (controparte con `@server` diverso da `im_server_id` locale), il mittente usa **forma FQDN** sulla propria copia — non `paolo` bare. Coerente con ciò che il destinatario vede e con `from_address` Gotham.

### 7.6 Allow list

- Una voce = un `allowed_address` lowercase; gate su indirizzo, non UUID.
- `mario` e `mario@arkham-im.fly.dev` = due voci distinte.

### 7.7 Schema target (prodotto)

DB attuale (`peer_profile_id` + `peer_external_address`, allow list UUID, rubrica snapshot) = **deriva implementativa**.

**`messages`**

| Colonna | Ruolo |
|---------|--------|
| `peer_address` text nullable | Chiave conversazione. **NULL** solo broadcast storico gruppo (SYS-GROUP-023); **NOT NULL** su 1:1 e erogazione |
| `author_address` text NOT NULL | Identità mittente come indirizzo |
| `author_id` uuid nullable | Solo flussi gruppo (erogazione, `original_author_id`); **NULL** su 1:1 |

Rimuovere (§1.2): `peer_profile_id`, `peer_external_address`, split allow list/contacts, RPC UUID come chiave chat.

**`reception_allowlist`:** `allowed_address` text NOT NULL; UNIQUE `(archive_user_id, allowed_address)`.

**`contacts`:** `address` text NOT NULL; UNIQUE `(archive_user_id, address)`. Rimuovere snapshot e split locale/federato.

### 7.8 RPC account

- Parametro unificato **`peer_address` text** — niente UUID come chiave conversazione.
- `list_inbox`, `list_peer_messages`, `mark_peer_read`, send: su `peer_address`.
- Unread: «in entrata» via `author_address` / confronto archivio, non solo `author_id` UUID.

### 7.9 Client — identità e presentazione

- `ChatPeer` con indirizzo canonico senza `profiles.id`.
- **Nessun profilo shadow** in `profiles` per peer remoti.
- `get_profiles(addresses[])` → dati pubblici; fallback → indirizzo grezzo.
- Inbox, rubrica, overlay, header: stesso batch `get_profiles`.
- Navigation / realtime / scope: keyed su `peer_address`.
- Push / deep link: keyed su `peer_address` (§7.19) — niente `peerProfileId`.

### 7.10 Rubrica = solo indirizzo

`contacts` salva soltanto `address` lowercase — non nome, avatar, né `linked_profile_id`.

### 7.11 `get_profiles` (batch)

```sql
get_profiles(p_addresses text[]) → setof { address, display_name, avatar_url, … }
```

Profilo remoto = interazione federata (tre piani come messaggi); risposta RPC, non INSERT in `profiles`. Wire profilo: kind/endpoint dedicato (non in `gotham.proto` oggi) — passo 5.

Inbox mostra indirizzo subito; arricchimento async.

### 7.12 Profilo pubblico — sempre (consent-first)

- `get_profiles` **non** gated da allow list.
- Allow list governa **recapito messaggi**, non visibilità profilo.
- Federazione: istanza origine serve profilo senza gate allow list del richiedente.

### 7.13 Link e shareable-link (decisione chiusa)

- `#indirizzo` e `#indirizzo/chat` per **qualsiasi** indirizzo valido, incluso `user@other-server`.
- **Non** 404 solo perché il peer non ha `profiles.id` locale.
- Apertura: `peer_address` dal fragment → chat/overlay; `get_profiles` in async; fallback indirizzo grezzo.
- Prima del passo 5 Gotham: ramo locale di `get_profiles`; federato mostra indirizzo finché il wire profilo non è live.

Oggi `PROM-SHAREABLE-LINK-006` e `shareable_link_machine` (rifiuto server remoto) sono **deriva** — amend + implementazione (§10).

### 7.14 Equivalenza forme link vs chiave messaggistica (decisione chiusa)

Due livelli distinti — non contraddizione da ridiscutere:

| Livello | `mario` vs `mario@mio_server` |
|---------|-------------------------------|
| **Link / lookup profilo locale** | Entrambe valide; se `@server` = istanza corrente, stesso profilo (`shareable_link.dart`: stesso `localUsername`, `normalizedAddress` può differire) |
| **Chiave `peer_address` / allow list / inbox / storico** | **Distinte** — stringhe diverse = conversazioni diverse (§7.2) |
| **Link in uscita (Condividi)** | Forma canonica preferita: bare `username` (`canonicalShareableAddress`, `PROM-SHAREABLE-LINK-030`) |

Amend SDD: esplicitare in `PROM-SHAREABLE-LINK` e `PROM-CHAT-PEER-KEY` — non unificare i due livelli.

### 7.15 Dati esistenti (decisione chiusa — 2026-09-13)

**Nessuna migrazione conversazioni.** Clean break §1.2:

- **Cancellare** `messages`, `outbox` collegata, `reception_allowlist`, `contacts` (e tabelle derivate messaggistica) su DB dev/demo.
- **Conservare** account (`auth.users`, `profiles`).
- Schema nuovo con sole colonne `*_address`; niente backfill da `peer_profile_id`.
- Dopo il wipe, `mario` e `mario@arkham` restano **due chat distinte** se create separatamente (§7.2).

### 7.16 Architettura a tre piani

```text
ACCOUNT (client + RPC)
  → scrivo a indirizzo X / get_profiles([…])
  → copia mittente + outbox

DELIVERY (worker)
  → @server → interno o Gotham

RECEPTION API (unica)
  → materializza messaggio destinatario
  → serve profilo pubblico (lookup locale o risposta federata)
```

### 7.17 Ordine di lavoro

1. Amend SDD + dominio (§7)
2. Reception API + RPC su indirizzo
3. Client su indirizzo + `get_profiles` (ramo locale)
4. Allow list su indirizzo
5. Worker Gotham (messaggi + profilo federato)

Gotham prima dei punti 1–3 → messaggi in DB che inbox/client non mostrano.

### 7.18 Gruppi — stesso modello account (chiusa 2026-09-13)

**Tutti gli account** — umani e gruppi — rientrano in questo drift. Nessun regime speciale per `SYS-GROUP` a livello identità lato utente.

| Aspetto | Regola |
|---------|--------|
| Identità gruppo | `@username` come qualsiasi account (`domain/groups/glossary.md`) |
| Chat umano → gruppo | `peer_address` = indirizzo gruppo (es. `team` o `team@arkham-im.fly.dev` secondo §7.2) |
| Inbox / allow list / compose / link | Stesse regole §7.1–§7.2 |
| Archivio interno gruppo | Bounded context separato (`SYS-GROUP`: broadcast, righe senza `peer_address` controparte umana) — **non** esenta il gruppo dall'identità address-based verso l'esterno |

Amend: `domain/groups/invariants.md` §4, `SYS-GROUP`, RPC e client gruppi — allineare a `peer_address` per la faccia «account» del gruppo.

### 7.19 Push e notifiche (chiusa 2026-09-13)

- Payload push e deep link: **`peerAddress`** (stringa indirizzo lowercase), non `peerProfileId`.
- **Nessun periodo dual-read** — il sistema si adatta al nuovo contratto; non mantenere lettura parallela UUID.
- Amend: `push-payload.md`, `SURF-NOTIFICATIONS`, `push_web.dart`, `push_deep_link.dart`, service worker.

### 7.20 Recap

```text
IDENTITÀ     peer_address / author_address  →  inbox, chat, allow list, compose, push
             author_address copia mittente   →  forma che fa fede nella comunicazione (§7.5b)
GRUPPI       stesso modello account          →  peer_address verso gruppo; archivio interno separato
RUBRICA      contacts.address only
PRESENTAZIONE get_profiles(addresses[])     →  pubblico; fallback indirizzo
PUSH         peerAddress only                →  no dual-read peerProfileId
VIETATO      profilo shadow; rubrica come cache profilo; get_profiles gated da allow list
```

---

## 8. Audit documentazione (2026-09-12 / agg. 2026-09-13)

| Documento | Stato vs §7 | Azione |
|-----------|-------------|--------|
| `mailbox-inbox-outbox-spec.md` § Identità chat | Allineato | — |
| `mailbox-inbox-outbox-spec.md` § Migrazione | Allineato §7.15 | — |
| `mailbox-inbox-outbox-spec.md` tabella modello attuale | Deriva (`peer_profile_id`) | Amend |
| `address-based-messaging.md` | Deriva GROUP BY UUID | Amend ADR |
| `no-internal-external-chat-distinction.md` | Routing su due colonne | Amend |
| `gotham-protocol.md` §4–5 | Allineato inbound/wire; §5.4 split colonne obsoleto | Amend §5.4 |
| `PROM-CHAT-PEER-KEY` | Contraddittorio | Amend |
| `SYS-MAILBOX`, `SYS-RECEPTION`, `SYS-CONTACTS`, `SYS-PROFILE` | Deriva | Amend |
| `SYS-GROUP`, `domain/groups/` | `peer_profile_id` lato chat; identità `@username` in dominio | Amend §7.18 |
| `PROM-PEER-PROFILE`, `PROM-CONVERSATION-SCOPE` | UUID-centric | Amend |
| `PROM-SHAREABLE-LINK-002` / `-006` | Tensione con §7.13–7.14 | Amend (regola a strati) |
| `contracts/schema.md`, `rpc.md` | Deriva | Amend |
| `push-payload.md`, `SURF-NOTIFICATIONS` | `peerProfileId` UUID | Amend §7.19 |
| `domain/messaging/`, `navigation/`, `contacts/`, `federation/`, `profile/`, `groups/` | UUID / snapshot | Amend |
| `guides/shareable-link.md` | Lookup locale + NotFound | Amend |
| `PROJECT_MAP.md` | `peer_profile_id` | Amend post-SDD |
| SQL `list_inbox()` | Solo `peer_profile_id IS NOT NULL` | Migrazione |
| Client (`ChatPeer`, push, shareable-link) | UUID / lookup locale | Implementazione |

---

## 9. Domande aperte

**Nessuna** — review 2026-09-13.

Le quattro voci della quarta passata sono chiuse in §7:

| Ex-ID | Risoluzione | Sezione |
|-------|-------------|---------|
| D1 Gruppi | Stesso modello account; tutti gli account nel drift | §7.18 |
| D2 Copia mittente uscita | `author_address` = forma che fa fede (FQDN se federato) | §7.5b |
| D3 Push | Solo `peerAddress`; niente dual-read | §7.19 |
| D4 «Per ora» §7.2 | Regola valida nel modello corrente; non voce da riaprire | §7.2 |

### 9.1 Catalogo completo domanda → risposta (review 2026-09-13)

Tutte le domande emerse in review (inclusa la lista numerata D–N). **Stato: chiuse** — risposte allineate a §7, §1.2, §7.15.

---

#### A — Contraddizioni documentali

| ID | Domanda | Risposta |
|----|---------|----------|
| **A1** | `mario` vs `mario@arkham` nei link: vale l’«equivalenza» di `PROM-SHAREABLE-LINK-002` o la separazione chat di §7.2? | **Due livelli distinti, non in competizione** (§7.14). **Link / lookup profilo locale:** entrambe le forme valide se `@server` = istanza corrente → stesso profilo pubblico (`localUsername`). **Chiave messaggistica** (`peer_address`, allow list, inbox, storico): **stringhe distinte** → chat distinte. **Link in uscita (Condividi):** forma preferita bare `username` (`PROM-SHAREABLE-LINK-030`). La domanda «quale vince» era mal posta: il fragment `#indirizzo/chat` è `peer_address` letterale; non esiste equivalenza tra forme a livello chat. |
| **A2** | Cos’è «§7 obsoleto» nel TEMP? | Era la **bozza pre-review** («Modello target da concordare») con regole contraddittorie (una sola chiave per encoding; split `peer_profile_id` / `peer_external_address`). **Revocata** e sostituita dal **§7 attuale** («Decisioni di modello chiuse»). Non usare la vecchia struttura §15 parallela. |
| **A3** | Gotham è indietro rispetto alla correzione massiva? | Il **wire** (envelope, dedup, HTTP) resta valido. **§5.4 e mapping prodotto** (split colonne, RPC `*_external_*`) sono **pre-§7** e vanno **riscritti** nello stesso workstream (§8, §1.2). Amend `gotham-protocol.md` + `gotham.proto` insieme a schema/RPC client — non patch parziale né solo worker runtime. |

---

#### B — Schema `messages`: `author_id`, unread, lettura

| ID | Domanda | Risposta |
|----|---------|----------|
| **B1** | `author_id` nei messaggi 1:1? | **`author_id` NULL su 1:1.** Identità messaggio = `author_address` (§7.7). `author_id` valorizzato **solo** flussi gruppo (erogazione, `original_author_id`) — SYS-GROUP. Il delivery risolve username → profilo in transazione senza persistere UUID come chiave. |
| **B2** | Regola «in entrata» / `unread_count`? | **Entrata** = messaggio non scritto dal titolare archivio, determinato via **`author_address`**, non `author_id` UUID (§7.8). Per 1:1: confronto con l’identità mittente attesa (§7.4 destinatario, §7.5b mittente). `unread_count` = righe in entrata con `read_at IS NULL`. Gruppi: erogazione con `author_address` gruppo → entrata sulla persona. |
| **B3** | `mark_peer_read(peer_address)` segna tutto il thread? | **Sì.** UPDATE sul mio archivio: `peer_address = p_peer_address`, entrata, `read_at IS NULL` → `read_at = now()` + mint `read_receipt_id` per riga (§7.8). |
| **B4** | `author_address` sulla copia in uscita (mia)? | **Forma che fa fede nella comunicazione** (§7.5b) — **non** sempre bare: se Paolo compone verso `mario@blackgate-im.fly.dev`, sulla copia Paolo `author_address = paolo@arkham-im.fly.dev`; verso `mario` bare → `paolo`. Allineato a destinatario (§7.4) e wire Gotham. |

---

#### C — Migrazione dati esistenti

| ID | Domanda | Risposta |
|----|---------|----------|
| **C1** | Backfill `peer_address` da `peer_profile_id`? | **No.** Wipe messaggi; schema nuovo (§7.15). |
| **C2** | Backfill `author_address` su storico? | **No.** Stesso wipe §7.15. |
| **C3** | `allowed_profile_id` → quale forma? | **N/A.** Wipe `reception_allowlist`; schema nuovo con `allowed_address` (§7.15). |
| **C4** | `linked_profile_id` → quale forma? | **N/A.** Wipe `contacts`; schema nuovo con solo `address` (§7.15, §7.10). |
| **C5** | Big-bang o fase transitoria? | **Big-bang / clean break** (§1.2): niente colonne parallele, niente `@deprecated`, niente dual-path. |
| **C6** | Chat duplicate post-migrazione? | **N/A** (wipe). Se ricreate, `mario` e `mario@arkham` restano **due chat** (§7.2). |

---

#### D — Compose e validazione indirizzo

| ID | Domanda | Risposta |
|----|---------|----------|
| **D1** | Bare `mario` — quando validare esistenza profilo? | **Due percorsi.** (1) **Compose / rubrica «Scrivi» / inbox:** apre chat se sintassi indirizzo valida; storico vuoto ammesso; header via `get_profiles` async, fallback indirizzo grezzo (§7.9, §7.11). (2) **Primo invio bare locale:** RPC rifiuta se username non esiste su istanza. (3) **Link `#…` bare locale / `@mention`:** risoluzione profilo locale richiesta per link/mention bare — se username assente in `profiles` → 404 (`PROM-MESSAGE-MENTION-004`; link locale §7.14). (4) **Link `#user@other-server`:** apre verso `peer_address` federato senza lookup locale (§7.13). |
| **D2** | `mario@blackgate` — validazione compose? | **Solo sintassi indirizzo** per aprire chat. Gate allow list + delivery al invio/recapito. Nessun `profiles.id` locale richiesto (§7.1, §7.13). |
| **D3** | `mario@arkham` su Arkham vs `mario` bare? | **Entrambi accettati; chat distinte.** Delivery interno per `@mio_server` senza fondere stringhe (§7.2). |
| **D4** | Invio a se stesso? | **Bloccato.** RPC invio rifiuta `peer_address` coincidente con indirizzo del titolare (bare o FQDN). CHECK `allowed_address` ≠ propri indirizzi su allow list (§7.6, §7.7). |
| **D5** | Username inesistente su istanza remota? | Compose ammesso. Fallimento a **delivery** (outbox `failed_at` / errore Gotham) se irraggiungibile. Inbound: allow list **match letterale** — nessun alias tra forme (§7.5–7.6; gap errori §11). |

---

#### E — RPC e contratti API

| ID | Domanda | Risposta |
|----|---------|----------|
| **E1** | Naming RPC invio? | **`send_message_to_address(p_peer_address text, …)`** — sostituisce `send_message_to_profile` e `send_message_to_external_address`. Nessun alias deprecated (§1.2). |
| **E2** | `list_peer_messages` / `mark_peer_read`? | **Solo `p_peer_address text`.** Nessun overload UUID (§7.8). |
| **E3** | `get_peer_context`? | **Sostituito da `get_profiles(p_addresses text[])`** per presentazione pubblica (§7.11). Flag relazione allow list/contacts: query dedicate o campi nel batch — **non** chiave chat. Niente UUID come parametro conversazione. |
| **E4** | `find_profile_by_username` resta? | **Sì** — per `search_profiles`, aggiunta allow list/contatto locale, risoluzione link/mention bare. **Non** per chiave conversazione né inbox (§7.8). |
| **E5** | Nome reception API inbound? | **`materialize_inbound_message(...)`** — unificata locale + Gotham; solo delivery/gateway, non client (§7.16). Sostituisce helper split / `materialize_inbound_federated_message`. |

---

#### F — Push, realtime, code client

| ID | Domanda | Risposta |
|----|---------|----------|
| **F1** | Push payload → `peer_address`? | **Sì.** Breaking accettato; **nessun dual-read** `peerProfileId` (§7.19, §1.2). Amend `push-payload.md`, Edge, SW, client. |
| **F2** | Chiave runtime client? | **`recipientUserId\|peerAddress`** — `PushConversationKey`, outbound queue, `ConversationScope`, `ValueKey` chat (§7.9, §7.19). |
| **F3** | Realtime filtro chat? | **Sì** — subscription/filtro su `peer_address` (§7.9). |
| **F4** | Soppressione push in foreground? | **Sì** — confronto `activePeerAddress` (stringa), non UUID (§7.19). |

---

#### G — Display UI

| ID | Domanda | Risposta |
|----|---------|----------|
| **G1** | Titolo riga inbox — priorità? | (1) `get_profiles(peer_address)` → `display_name`; (2) fallback **`peer_address` grezzo**. Rubrica **non** fornisce titolo (§7.10: solo `address`). Niente join `profiles` per chiave UUID. |
| **G2** | Avatar peer federato? | Da **`get_profiles`** se disponibile; altrimenti placeholder/iniziali. **Nessun** fetch profilo shadow in `profiles` (§7.9, §7.12). |
| **G3** | Avatar peer locale senza UUID come chiave? | **Sì** — `get_profiles(['mario'])` arricchisce UI; chiave runtime resta `peer_address` (§7.9). |
| **G4** | Overlay profilo federato? | **Stesso overlay** per qualsiasi indirizzo: `get_profiles` async + allow + rubrica (`address` only) + «Inizia a chattare»; fallback indirizzo grezzo. **No** profilo shadow (§7.9, §7.12). |
| **G5** | `mario` vs `mario@arkham` in overlay? | **Due sessioni UI / due chat** coerenti con §7.2. |
| **G6** | Tap avatar autore in chat gruppo? | Header autore via **`original_author_id`** / `get_profiles` sull’indirizzo umano; semantica erogazione SYS-GROUP invariata (§7.18). |

---

#### H — Rubrica (`contacts`)

| ID | Domanda | Risposta |
|----|---------|----------|
| **H1** | Aggiunta locale dopo `search_profiles`? | Salva **`address = username` bare** lowercase del profilo scelto (§7.10). |
| **H2** | Aggiunta federata? | Form manuale: solo **`address`** (`user@server` lowercase). **Niente** `display_name` in tabella — presentazione da `get_profiles` (§7.10). |
| **H3** | Stesso soggetto, due voci `mario` + `mario@arkham`? | **Ammesso** — indirizzi distinti (§7.2). |
| **H4** | «Scrivi» da rubrica? | Apre chat con **`peer_address = contacts.address` letterale** (§7.10). |
| **H5** | Avatar federato in rubrica? | **No colonna avatar** in `contacts` (§7.10). Avatar solo da `get_profiles` in UI. |

---

#### I — Allow list

| ID | Domanda | Risposta |
|----|---------|----------|
| **I1** | Aggiunta locale? | Come H1: **`allowed_address = username` bare** da `search_profiles` (§7.6). |
| **I2** | Aggiunta federata? | Form `user@server` → **`allowed_address` lowercase** (§7.6). |
| **I3** | Etichetta in «Persone consentite»? | **`get_profiles(allowed_address)`** se risolve; altrimenti indirizzo grezzo. Nessun `display_name` in tabella allow list. |
| **I4** | Toggle allow da scheda profilo? | Crea/rimuove riga con **`allowed_address` = indirizzo della sessione UI** (forma con cui è aperto il peer) (§7.6). |

---

#### J — Gruppi

| ID | Domanda | Risposta |
|----|---------|----------|
| **J1** | `famiglia` vs `famiglia@server` in allow list / compose? | **Stessa regola §7.2** — voci e chat distinte. |
| **J2** | Semantica delivery gruppo su modello indirizzo? | **`peer_address`** al posto di `peer_profile_id` per faccia «account» verso esterno; **`author_id` / `original_author_id` UUID** restano per erogazione interna; `author_address` per display dove serve (§7.7, §7.18). |
| **J3** | Broadcast storico gruppo — `peer_address`? | **NULL** sulla riga archivio gruppo (SYS-GROUP-023) — unica eccezione nullable (§7.7). |
| **J4** | Erogazione verso membri — `peer_address`? | Copia persona: **`peer_address` = indirizzo letterale del gruppo** nella relazione allow list (§7.18). |
| **J5** | Gruppo federato `famiglia@blackgate` — in scope? | **Modello sì** (identità address-based). **Recapito/erogazione cross-istanza** con worker Gotham — passo 5 (§7.17), stesso gate 1:1 federato. |
| **J6** | `list_inbox` messaggio erogato da gruppo? | Riga verso **`peer_address` del gruppo**; preview autore umano via `original_author_id` / `get_profiles` (SYS-GROUP-033, §7.18). |
| **J7** | Shell gruppo / storico interno? | Archivio `archive_user_id = gruppo`; UI autore da **`author_address` + `original_author_id`**; bounded context interno separato (§7.18). |

---

#### K — Link condivisibili

| ID | Domanda | Risposta |
|----|---------|----------|
| **K1** | `#mario@blackgate` su Arkham? | **Apre chat/profilo federato** verso `peer_address` letterale — **non** lookup locale (§7.13). |
| **K2** | Link in uscita — forma canonica? | **Bare `username`** per peer locali (`canonicalShareableAddress`, PROM-SHAREABLE-LINK-030). Non fonde le chat in compose (§7.14). |
| **K3** | `#mario/chat` vs `#mario@arkham/chat`? | **`peer_address` = stringa del fragment** (lowercase); chat distinte (§7.14). |
| **K4** | Profilo link federato cross-istanza? | Overlay/chat con **`get_profiles` async** + fallback grezzo; **non** 404 per assenza `profiles.id` locale (§7.13). |

---

#### L — Mention `@username`

| ID | Domanda | Risposta |
|----|---------|----------|
| **L1** | Tap `@mario` in bolla? | Apre chat con **`peer_address = mario`** (bare). Se username non in `profiles` → **404** (`PROM-MESSAGE-MENTION-004`). Stesso percorso compose (`resolveAddress` + open). |
| **L2** | Mention `@mario@server` nel body? | **Non supportato.** Mention = `@username` bare valido (`AuthIdentity.isValidUsername`). Indirizzo completo solo via compose/link. |

---

#### M — Federazione

| ID | Domanda | Risposta |
|----|---------|----------|
| **M1** | Paolo→Mario cross-istanza — mittente visto da Mario? | **Sempre indirizzo completo wire** — es. `paolo@arkham-im.fly.dev` (§7.5, §7.5b). |
| **M2** | Allow list — match tra forme? | **Solo letterale** su `allowed_address`; **nessun** alias `mario` ↔ `mario@server` (§7.6). |
| **M3** | Display mittente federato in inbox? | **`get_profiles(author_address)`** poi fallback `author_address` grezzo (§7.9, G1). |

---

#### N — Processo

| ID | Domanda | Risposta |
|----|---------|----------|
| **N1** | Prossimo deliverable? | **Amend SDD `draft`** (promesse + `contracts/` + dominio) **prima** del codice; UML/statechart **nello stesso passaggio** prima di implementazione che cambia comportamento (§10.1; regole modello repo). |
| **N2** | TEMP vs SDD? | Questo file accumula decisioni → **distillazione in promesse `approved`** → **eliminazione TEMP** (§14). |
| **N3** | Promesse satellite in scope amend? | **Sì** — `PROM-SHAREABLE-LINK`, `PROM-MESSAGE-MENTION`, `PROM-PEER-PROFILE`, `SYS-PUSH` / `push-payload`, `PROM-CONVERSATION-SCOPE`, SURF-* — clean break §1.2; niente semantica UUID residua. |

---

**Totale: 52 domande — 52 risposte chiuse.** Riferimento modello: §7; implementazione: §1.2, §10.

---

## 10. Lavoro da fare (non sono domande aperte)

### 10.1 Formalizzazione SDD e dominio

Scrivere in promesse `approved` tutto §7, incluso:

- Riconciliazione esplicita `PROM-SHAREABLE-LINK` / `PROM-CHAT-PEER-KEY` (§7.14)
- Revoca comportamento 404/remoto su link (§7.13)
- `get_profiles`, rubrica solo `address`, profilo pubblico sempre
- `author_address` copia mittente (§7.5b)
- Gruppi come account address-based (§7.18)
- Push `peerAddress` senza dual-read (§7.19)
- Schema §7.7, RPC §7.8
- Registry, dominio, UML (`groups/`, `messaging/`, `navigation/`, `federation/`)

### 10.2 Implementazione (dopo `approved`)

| Livello | Azione |
|---------|--------|
| SQL | Schema §7.7; migrazione dev §7.15; RPC su `peer_address`; `get_profiles` |
| Client | `peer_address`; batch `get_profiles`; shareable-link remoto; push `peerAddress`; chat verso gruppo |
| Gotham | Passo 5 |

### 10.3 File codice

**Client:** `chat_peer.dart`, `profile_summary.dart`, `compose_service.dart`, `compose_address.dart`, `navigation_coordinator.dart`, `conversation_scope_guard.dart`, `mailbox_message_filter.dart`, `push_web.dart`, `push_deep_link.dart`, `peer_message_service.dart`, `profile_service.dart`, `contact_service.dart`, `shareable_link_machine.dart`, `machines/navigation/`, `machines/messaging/`, `peer_profile_overlay.dart`, `contacts_screen.dart`, `inbox_panel.dart`, test correlati.

**Supabase:** `list_inbox`, `list_peer_messages`, `mark_peer_read`, send su `peer_address`, `get_profiles(p_addresses text[])`, reception API, migrazione §7.7.

### 10.4 Post-merge

Eliminare questo file TEMP.

---

## 11. Gap correlati (scope distinto)

1. Reception allow list su schema UUID attuale
2. READ/REACTION outbound Gotham
3. Media ingest federato
4. Errori outbox federato
5. `SYS-FEDERATION-*` in backlog
6. Wire Gotham per `get_profiles` (§7.11)

Prerequisito: chiave indirizzo (§7). Contratto `get_profiles` al passo 1 anche se ramo federato al passo 5.

---

## 12. Scenario demo Arkham ↔ Blackgate

1. A aggiunge `b@blackgate-im.fly.dev` in allow list.
2. B aggiunge `a@arkham-im.fly.dev` in allow list.
3. A compone `b@blackgate-im.fly.dev` → stessa UI chat locale.
4. Invio → copia A: `peer_address` = `b@blackgate-im.fly.dev`, `author_address` = `paolo@arkham-im.fly.dev` (§7.5b); outbox; Gotham.
5. B riceve → `peer_address` = `a@arkham-im.fly.dev`, `author_address` = `paolo@arkham-im.fly.dev`.
6. Inbox B: riga con indirizzo; `get_profiles` arricchisce (passo 5) o grezzo.
7. B apre → `mark_peer_read` → READ federato → A ✓✓ blu.

Oggi 3–7 falliscono.

---

## 13. Riferimenti

| Risorsa | Path |
|---------|------|
| Identità chat | `docs/architecture/mailbox-inbox-outbox-spec.md` |
| Migrazione dev | `mailbox-inbox-outbox-spec.md` § Migrazione |
| ADR | `docs/decisions/address-based-messaging.md`, `no-internal-external-chat-distinction.md` |
| Promesse | `PROM-CHAT-PEER-KEY`, `SYS-MAILBOX`, `SYS-RECEPTION`, `SYS-CONTACTS`, `SYS-PROFILE`, `PROM-SHAREABLE-LINK`, `PROM-PEER-PROFILE` |
| Gruppi | `docs/domain/groups/`, `SYS-GROUP` |
| Federazione | `docs/architecture/gotham-protocol.md` |
| Contratti | `docs/specs/contracts/schema.md`, `rpc.md`, `push-payload.md` |
| Shareable-link (codice) | `client/lib/utils/shareable_link.dart`, `shareable_link_machine.dart` |
| Istanze demo | `client/deploy/README.md` § Istanze demo |

---

## 14. Istruzioni post-review

1. ~~Risolvere §9~~ — fatto (2026-09-13).
2. Distillare §7 in SDD `approved` (§10.1).
3. Eliminare questo file dopo promozione.
4. Implementare solo dopo `approved` + conferma scrittura (regola 0 / SDD).

---

*File temporaneo — non fa parte della documentazione canonica (vedi `docs/SSOT.md`).*
