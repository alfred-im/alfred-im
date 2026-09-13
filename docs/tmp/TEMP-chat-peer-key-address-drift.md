# TEMP — Deriva chiave conversazione: indirizzo vs `profileId`

**Stato:** bozza temporanea — da eliminare dopo promozione in SDD `approved`  
**Revisione:** 2026-09-13 (quinta passata — §9 risolto; modello completo per SDD)  
**Audience:** revisione modello / SDD / implementazione federazione  
**Non è SSOT** — vedi `docs/SSOT.md`. Contenuto da distillare in dominio, promesse e contratti.

**Legenda sezioni**

| Sezione | Contenuto |
|---------|-----------|
| §7 | Decisioni di modello **chiuse** (review 2026-09-12) — da promuovere in SDD |
| §8 | Audit documentazione — tensioni verificate |
| §9 | Domande aperte — **nessuna** (risolte 2026-09-13) |
| §10 | Lavoro da fare — formalizzazione SDD + implementazione |

---

## 1. Sintesi

**Direttiva vincolante** (architettura + ADR): conversazione 1:1 = `(mio account, indirizzo controparte)` — `username` o `user@server`. Nessuna tipologia «chat locale» vs «chat federata» in UI, account, inbox, allow list o RPC.

**Deriva:** implementazione e promesse `implemented` hanno cristallizzato la chiave su `peer_profile_id` (UUID). Con ogni peer su profilo locale funzionava; la federazione Arkham ↔ Blackgate espone il disallineamento.

**Correzione:** chiave canonica = **`peer_address`** (lowercase). Presentazione = **`get_profiles(addresses[])`** (batch, profilo pubblico sempre). Gotham = solo trasporto. Ordine: SDD → reception API → client → allow list → worker Gotham.

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
| `peer_address` text NOT NULL | Chiave conversazione |
| `author_address` text NOT NULL | Identità mittente come indirizzo |
| `author_id` uuid nullable | Solo casi tecnici (es. SYS-GROUP) |

Rimuovere `peer_profile_id` / `peer_external_address` come identità chat.

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

### 7.15 Migrazione dati (decisione chiusa — fonte mailbox spec)

`mailbox-inbox-outbox-spec.md` § Migrazione:

- **Solo DB dev** — niente produzione da preservare.
- «Migra e basta» — niente doppia scrittura obbligatoria.
- Backfill dev: `peer_address` da `profiles.username` dove esiste `peer_profile_id`.
- Storico `mario` + `mario@arkham` verso stesso profilo: **restano due conversazioni** (coerente §7.2) — nessuna fusione.

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
