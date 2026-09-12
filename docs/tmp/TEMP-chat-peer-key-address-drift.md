# TEMP — Deriva chiave conversazione: indirizzo vs `profileId`

**Stato:** bozza temporanea per review — **da rimuovere** dopo promozione in dominio / SDD `approved`  
**Data:** 2026-09-12 (ultimo aggiornamento: 2026-09-12 — rubrica + `get_profiles`)  
**Branch:** `main` (commit dedicato, file eliminabile)  
**Audience:** revisione modello / SDD / implementazione federazione

---

## 1. Sintesi

Alfred ha una **direttiva vincolante** (address-based messaging + nessuna distinzione chat locale/federata): la conversazione 1:1 si identifica con **(mio account, identità account controparte)** — `username` sulla stessa istanza oppure `user@server` su altra istanza Alfred.

L'implementazione e parte delle promesse SDD hanno invece **cristallizzato** la chiave su `peer_profile_id` (UUID in `profiles`), perché fino alla federazione ogni controparte aveva sempre un profilo locale. Non è un buco del protocollo Gotham: è una **deriva preesistente** che la federazione rende visibile.

**Correzione di modello richiesta:** riallineare chiave conversazione all'**indirizzo account**, con `peer_profile_id` / `peer_external_address` come rappresentazioni storage (routing), non come due tipi di chat.

---

## 2. Direttiva originale (cosa era già deciso)

### 2.1 Identità chat = indirizzo, non thread

Fonte: `docs/architecture/mailbox-inbox-outbox-spec.md` § Identità chat (vincolante)

- Serve solo: (1) il mio account, (2) l'altro account come **indirizzo** — `username` o `username@server`.
- Nessun `thread_id` client.
- `peer_profile_id` in DB è **ottimizzazione interna** (indici, raggruppamento), non identità esposta.

### 2.2 Nessuna tipologia «chat locale» vs «chat federata»

Fonte: `docs/decisions/no-internal-external-chat-distinction.md`

- Vietato ramificare comportamento UI/semantica per tipologia locale/federata.
- Routing implicito:

| Destinazione      | Compose / storage              | Driver recapito   |
|-------------------|--------------------------------|-------------------|
| Stessa istanza    | `username` → `peer_profile_id` | Worker locale     |
| Altra istanza     | `user@server` → `peer_external_address` | Worker Gotham |

L'utente vede **persone e indirizzi**, non protocolli.

### 2.3 Messaggistica per indirizzo

Fonte: `docs/decisions/address-based-messaging.md`

- Si scrive a un **indirizzo**; rubrica non abilita né blocca messaggistica.
- Inbox = aggregazione on-read sul proprio archivio.
- Federato `username@server`: pianificato, `unsupported` fino a gateway/worker.

### 2.4 Implicazione logica

La **chiave concettuale** della conversazione è sempre:

```text
(io, identità controparte)
```

dove identità controparte è:

- **locale:** `username` (risolvibile in `profiles.id` sulla stessa istanza)
- **federato:** `user@im_server_id` (nessun `profiles.id` obbligatorio sulla tua istanza)

Non esistono due modelli di chat — esistono due **encoding** dello stesso concetto nel persistence layer.

---

## 3. Dove si è creata la deriva

### 3.1 Promessa SDD incoerente con la mailbox spec

Fonte: `docs/specs/promises/product/PROM-CHAT-PEER-KEY.md` (`implemented`)

| ID | Testo | Problema |
|----|-------|----------|
| PROM-CHAT-PEER-KEY-001 | Chat = `(io, indirizzo peer)` | Allineato alla direttiva |
| PROM-CHAT-PEER-KEY-002 | Chiave canonica = **identificativo profilo** del peer | **Contraddice** mailbox spec e -001 per peer senza profilo locale |
| PROM-CHAT-PEER-KEY-003 | Stesso `profileId` vuoto/pieno | Assume sempre UUID profilo |

La sezione «Problema / obiettivo» della promessa dice «indirizzo peer» ma aggrega inbox «per `peer_profile_id`» — mix di due livelli di astrazione.

### 3.2 SYS-MAILBOX aggrega solo su profilo locale

Fonte: `docs/specs/promises/system/SYS-MAILBOX.md`

- **SYS-MAILBOX-034:** `list_inbox()` GROUP BY `peer_profile_id` (locale).
- **SYS-MAILBOX-011:** `peer_external_address` «per federazione futura (non usata UI)».
- **SYS-MAILBOX-047 / 038:** unread e `mark_peer_read` usano `author_id` / `peer_profile_id` UUID.

Le promesse mailbox **non** estendono aggregazione/lettura a `peer_external_address`.

### 3.3 Client: `ChatPeer` = profilo locale obbligatorio

File: `client/lib/models/chat_peer.dart`, `client/lib/models/profile_summary.dart`

- `ChatPeer` wrappa `ProfileSummary` con `id` obbligatorio (`profileId`).
- `ProfileSummary.fromInboxRow` legge `peer_profile_id` — non costruisce peer solo da `peer_external_address`.
- Navigation, push, realtime, scope chat usano `peerProfileId` come chiave runtime (`ValueKey`, filtri subscription, deep link push).

### 3.4 Compose blocca il federato

File: `client/lib/services/compose_service.dart`, `client/lib/utils/compose_address.dart`

- `parseComposeAddress` riconosce `user@server`.
- `resolveAddress` e `peerFromContact` lanciano `Indirizzo esterno non ancora supportato`.
- La deriva non è «mancanza Gotham» sola: il client **non ha mai** modellato `ChatPeer` senza `profiles.id`.

### 3.5 SQL: inbox esclude righe solo federate

File: `supabase/migrations/20260908100000_gotham_native_drop_protocol.sql` — `list_inbox()`

- CTE `direct` filtra `m.peer_profile_id is not null`.
- Righe con solo `peer_external_address` (senza `peer_profile_id`) **non entrano** in inbox.
- `distinct on (d.peer_profile_id)` — impossibile raggruppare per indirizzo esterno.

`contracts/rpc.md` documenta `list_inbox` con righe dove `peer_profile_id IS NOT NULL **oppure** peer_external_address IS NOT NULL` — **documentazione desiderata ≠ implementazione attuale**.

### 3.6 RPC storico/lettura solo UUID

- `list_peer_messages(p_peer_profile_id uuid)`
- `mark_peer_read(p_peer_profile_id uuid)` — filtra `author_id = p_peer`

Nessuna variante per `peer_external_address` / indirizzo normalizzato.

### 3.7 Autore messaggio: `author_id NOT NULL`

Schema: `messages.author_id uuid not null references profiles`

Gotham §5.4 propone inbound con `author_id` null + `author_external_address` — **non implementato**, in tensione con SYS-MAILBOX-001 e con logica unread (`author_id <> archive_user_id`).

### 3.8 Rubrica e profilo: deriva su snapshot e UUID

Fonte: `docs/specs/promises/system/SYS-CONTACTS.md` (`implemented`), `ProfileService.fetchSummariesByIds`

| Aspetto | Stato attuale | Modello target |
|---------|---------------|----------------|
| `contacts` locale | `linked_profile_id` + `display_name` / `avatar_url` snapshot | **Solo `address`** (text lowercase) |
| `contacts` federato | `external_address` + `display_name` obbligatorio | **Solo `address`** |
| Dati profilo in UI | Join su `profiles` o campi denormalizzati in rubrica / `list_inbox` | **`get_profiles(addresses[])`** — batch unificato |
| Peer overlay | Solo peer con `profiles.id` locale | Stesso `get_profiles` per **qualsiasi** indirizzo |
| Remoto | Nessun overlay; nessun fetch federato profilo | Interazione federata (§ 16) — **no** profilo shadow |

La rubrica oggi **duplica** dati di presentazione; nel modello corretto è solo un elenco di indirizzi. Nome, avatar, pronomi non vivono in `contacts`.

---

## 4. Perché la federazione espone il bug (non lo crea)

Prima della federazione:

- Ogni peer conversabile aveva `profiles.id` sulla stessa istanza.
- `username` ↔ `profileId` era biiezione pratica 1:1.
- Usare UUID come chiave runtime **funzionava** senza violare l'esperienza utente.

Con federazione (Arkham ↔ Blackgate):

- `mario@blackgate-im.fly.dev` non ha `profiles.id` su Arkham.
- Non si può aprire chat, inbox, lettura, push, scope con solo `peerProfileId`.
- Il wire Gotham e `peer_external_address` in schema **esistono**; il **modello client + RPC inbox** no.

La federazione è il test di regressione della direttiva address-based.

---

## 5. Mappa sintomi → causa radice

| Sintomo osservabile | Causa radice |
|---------------------|--------------|
| Compose `user@server` → unsupported | Chiave runtime = profilo locale, non indirizzo |
| Inbox non mostra chat federate | `list_inbox` GROUP BY / filtro solo `peer_profile_id` |
| `list_peer_messages` inutilizzabile per federato | Parametro solo UUID |
| `mark_peer_read` non applicabile | Assume `author_id` e `peer_profile_id` UUID |
| `ChatPeer` non costruibile per peer remoto | `ProfileSummary.id` obbligatorio |
| Push / navigation / realtime | Pipeline keyed su `peerProfileId` |
| Link `#user@server/chat` cross-istanza | Shareable-link risolve su `find_profile_by_username` locale |
| Unread count errato su inbound federato (futuro) | `author_id <> archive_user_id` con `author_id` null |
| PROM-CHAT-PEER-KEY «implemented» vs federazione | Promessa chiusa sul caso locale |
| Rubrica mostra nome senza `get_profiles` | `contacts` persiste snapshot / `linked_profile_id` invece di solo indirizzo |
| Inbox N+1 profili | `list_inbox` join `profiles` per peer; manca batch per indirizzo |
| Overlay profilo remoto assente | Nessun `get_profiles` federato; dominio contacts vieta overlay federato |

---

## 6. Cosa **non** è il problema

- **Gotham wire** (envelope, id federativi, dedup, HTTP ack): coerente per messaggi 1:1 testo/location/read/reaction.
- **Due campi DB** `peer_profile_id` vs `peer_external_address`: corretti come routing implicito (ADR no-internal-external).
- **Outbox unica** locale/federata: modello mailbox § Consegna è allineato.
- **Allow list federata** (`allowed_external_address`): descritta in `gotham-protocol` §5.4 ma è un **altro** gap (reception), non la chiave conversazione — correlato ma distinto.

---

## 7. Modello target (da concordare prima di implementare)

### 7.1 Chiave canonica conversazione 1:1

```text
ConversationKey = {
  archiveUserId: uuid,           // io
  peerAddress: NormalizedAddress // identità account controparte
}

NormalizedAddress =
  | Local(username)              // lower(username), stessa istanza
  | Federated(user, im_server_id) // lower(user)@lower(server)
```

**Regola:** una sola chiave per controparte; mai due chat per lo stesso indirizzo con encoding diversi.

### 7.2 Mapping storage (invariato come intento ADR)

| `peerAddress` | `messages.peer_profile_id` | `messages.peer_external_address` |
|---------------|----------------------------|----------------------------------|
| Local         | valorizzato                | null                             |
| Federated     | null                       | valorizzato                      |

Mutua esclusione come già documentato post-drop `protocol`.

### 7.3 Client

- `ChatPeer` (o equivalente) deve essere costruibile con **indirizzo canonico** senza `profiles.id`.
- **Nessun profilo shadow** in `profiles` per peer remoti.
- **Presentazione:** `get_profiles(addresses[])` (§ 16) → dati pubblici; finché in flight o assente → **indirizzo grezzo**. La rubrica **non** fornisce nome/avatar — solo l’indirizzo da arricchire.
- Scheda profilo peer (overlay), inbox, rubrica: **stesso** servizio batch `get_profiles` — non API separate per schermata.
- Navigation / push / realtime / scope: keyed su `ConversationKey` o stringa canonica `peerAddress`, non solo UUID.

### 7.4 RPC / inbox

- `list_inbox`: raggruppare per chiave controparte = `coalesce(peer_profile_id::text, lower(peer_external_address))` o due branch unificati in output.
- `list_peer_messages` / `mark_peer_read`: accettare identificatore controparte = UUID **oppure** indirizzo federato normalizzato (overload o parametro unificato).
- Unread: definire «in entrata» senza dipendere solo da `author_id` UUID — es. `author_id = auth.uid()` per uscita, altrimenti entrata; oppure `author_external_address` / `peer_external_address` per federato.

### 7.5 Autore inbound federato

Allineare a Gotham §5.4:

- `author_external_address` su messaggi in ingresso.
- CHECK: uscita → `author_id = archive_user_id`; entrata locale → `author_id = peer_profile_id`; entrata federata → `author_external_address` valorizzato.
- `isMine` in UI: `author_id == currentUserId` (locale) — non usare solo confronto author per federato inbound.

---

## 8. Documenti in tensione (da riallineare)

| Documento | Azione suggerita |
|-----------|------------------|
| `PROM-CHAT-PEER-KEY` | Amend: chiave = indirizzo normalizzato; `profileId` dettaglio locale |
| `SYS-MAILBOX` | Amend: SYS-MAILBOX-034/035/036/038/047 per `peer_external_address` |
| `contracts/rpc.md` | Allineare a implementazione reale dopo amend |
| `contracts/schema.md` | `author_external_address`, CHECK autore |
| `docs/domain/messaging/glossary.md` | Termine «chiave conversazione» esplicito |
| `docs/domain/reception/` | Separato: allow list esterna |
| `SYS-CONTACTS` | Amend: rubrica = solo `address`; rimuovere snapshot e `linked_profile_id` come identità |
| `SYS-PROFILE` | Amend: `get_profiles(addresses[])` batch locale + federato; deprecare batch solo per UUID come unico percorso |
| `PROM-PEER-PROFILE` | Overlay per indirizzo via `get_profiles`; locale e remoto stesso percorso |
| `docs/domain/contacts/`, `docs/domain/federation/` | Rubrica = indirizzi; profilo = interazione federata |
| `SURF-CHAT`, `SURF-INBOX` | Binding su chiave indirizzo; display via `get_profiles` |
| `PROM-SHAREABLE-LINK` | Regola `#user@other-server` → compose federato, non lookup locale |

**Non** serve nuova tipologia chat in UI (resta vietata dall'ADR).

---

## 9. File codice toccati (riferimento implementazione futura)

Solo elenco — **nessuna modifica in questo commit**.

### Client

- `client/lib/models/chat_peer.dart`
- `client/lib/models/profile_summary.dart`
- `client/lib/services/compose_service.dart`
- `client/lib/utils/compose_address.dart`
- `client/lib/coordinators/navigation_coordinator.dart`
- `client/lib/utils/conversation_scope_guard.dart`
- `client/lib/utils/mailbox_message_filter.dart`
- `client/lib/utils/push_web.dart`, `push_deep_link.dart`
- `client/lib/services/peer_message_service.dart`
- `client/lib/services/profile_service.dart` — `get_profiles` batch per indirizzo
- `client/lib/services/contact_service.dart`
- `client/lib/machines/navigation/`, `machines/messaging/`
- `peer_profile_overlay.dart`, `contacts_screen.dart`, `inbox_panel.dart`
- Test: `compose_service_test.dart`, `conversation_scope_*`, navigation tests, `peer_profile_overlay_test.dart`

### Supabase

- `list_inbox()`, `list_peer_messages()`, `mark_peer_read()`
- Eventuale `send_message_to_external_address()` (Gotham §5.4)
- `reception_allowlist.allowed_external_address` (reception federata — gap correlato)
- `materialize_inbound_federated_message` + `author_external_address`
- `get_profiles(p_addresses text[])` — batch locale + federato

---

## 10. Gap correlati (stesso filone, scope distinto)

Questi emergono con la federazione ma **non** sono identici alla chiave conversazione:

1. **Reception allow list esterna** — schema oggi solo `allowed_profile_id`; Gotham §5.4 + SYS-RECEPTION-018 senza contratto SYSTEM completo.
2. **READ/REACTION outbound** verso peer — mapping outbox → envelope Gotham non dettagliato.
3. **Media ingest** — `media_url` sul wire insufficiente; mailbox § Media.
4. **Discovery / errori outbox** federato — 4xx/5xx, `failed_at`.
5. **SYS-FEDERATION-*** — solo backlog in `registry.md`.
6. **`get_profiles` federato sul wire** — nuovo kind o endpoint Gotham (§ 16.4); implementazione worker al passo 5.

Vanno in promesse/workstream separati; la chiave indirizzo è **prerequisito** per tutti. Il contratto `get_profiles` va definito al passo 1–2 anche se il ramo federato del delivery si implementa al passo 5.

---

## 11. Scenario demo Arkham ↔ Blackgate (cosa il modello deve permettere)

1. Utente A su Arkham aggiunge `b@blackgate-im.fly.dev` in allow list (quando reception federata esiste).
2. Utente B su Blackgate aggiunge `a@arkham-im.fly.dev` in allow list.
3. A compone `b@blackgate-im.fly.dev` → stessa UI chat di un peer locale.
4. Invio → copia mittente con `peer_external_address`; outbox `queued`; worker Gotham.
5. B riceve → copia destinatario con `peer_external_address` = `a@arkham-im.fly.dev`, `author_external_address` valorizzato.
6. Inbox di B mostra riga verso `a@arkham-im.fly.dev` senza `profiles.id` di A.
7. B apre chat → `mark_peer_read` → READ federato → A vede ✓✓ blu.

Oggi i passi 3–7 falliscono per deriva chiave (e reception/schema federato non completi).

---

## 12. Domande aperte per la conversazione di correzione

### Risolte in review chat (2026-09-12) — dettaglio § 15

| # | Domanda originale | Decisione |
|---|-------------------|-----------|
| 1 | Stringa canonica (`username` vs `user@server`) | Entrambe usabili; **nessuna equivalenza** tra forme (`mario` ≠ `mario@arkham-im.fly.dev`) |
| 2 | Profilo shadow per mittente remoto | **Nessun** `profiles.id` obbligatorio su istanza destinataria; display via **`get_profiles`**; fallback indirizzo grezzo (§ 16) |
| 3 | Overload RPC vs parametro text unificato | RPC account su **indirizzo** (`peer_address`); niente ramo UUID come chiave chat |
| 4 | Ordine di lavoro | Amend SDD chiave indirizzo → reception API → client → allow list → **poi** worker Gotham (§ 15.9) |
| 5 | Retrocompatibilità chat locali | Chiave = indirizzo; `profileId` non è identità conversazione |
| — | Normalizzazione / case | Input case insensitive; **persistenza sempre lowercase** (§ 15.10) |
| — | Schema DB | `peer_address`, `author_address`, `allowed_address` — niente split locale/federato (§ 15.11) |
| — | Allow list | Una voce = un `allowed_address` lowercase; gate su indirizzo, non UUID |
| — | Inbox | Raggruppa per **indirizzo controparte** da ogni lato (§ 15.3) |
| — | Ruolo Gotham | Solo trasporto cross-server; indirizzi completi sul wire (§ 15.7) |
| — | Architettura invio/ricezione | Account ignora interno/esterno; delivery sceglie driver; reception API unica (§ 15.6) |

### Risolte in review chat (2026-09-12, secondo giro) — dettaglio § 16

| # | Domanda | Decisione |
|---|---------|-----------|
| 6 | Cosa salva la rubrica | **Solo indirizzo** (`address` lowercase) — niente `display_name`, `avatar_url`, `linked_profile_id` come identità |
| 7 | Dove vivono i dati profilo (nome, avatar, pronomi) | **`get_profiles(addresses[])`** — stesso sistema della scheda profilo peer |
| 8 | `get_profile` vs batch | **`get_profiles` plurale** — una RPC per inbox, rubrica, overlay (anche batch da 1 elemento) |
| 9 | Profilo remoto = interazione federata | Sì — stesso percorso a tre piani dei messaggi (ACCOUNT → DELIVERY → RECEPTION), materializzazione = risposta profilo, non riga `profiles` locale |

### Ancora aperta (solo formalizzazione SDD)

Nessuna decisione di modello pendente su rubrica/profilo. Resta **scrittura** in amend `SYS-CONTACTS`, `SYS-PROFILE`, `PROM-PEER-PROFILE`, `SYS-MAILBOX`, dominio `contacts` / `federation` e `registry.md`.

---

## 15. Chiarimenti review chat (2026-09-12)

**Stato:** accordo di modello emerso in chat — da distillare in dominio / SDD `approved`; non SSOT finché non promosso.

### 15.1 Non esiste locale/federato — esiste l’indirizzo

- **Vietato** ragionare in termini di «chat locale» vs «chat federata» o «peer interno» vs «peer esterno» a livello account, UI, inbox, allow list, RPC account.
- Esiste solo la **stringa indirizzo** della controparte.
- L’unico modulo che distingue «questo `@server` è la mia istanza o un’altra» è il **delivery**, al momento del recapito (worker interno in-process vs HTTP Gotham verso altro server).
- Gotham **non** è un tipo di chat: è solo il trasporto tra server Alfred diversi.

### 15.2 Forme indirizzo — nessuna equivalenza

| Input utente | Significato |
|--------------|-------------|
| `mario` | Indirizzo sulla **stessa istanza** (username senza server esplicito) |
| `mario@arkham-im.fly.dev` | Indirizzo con server esplicito |
| `mario@blackgate-im.fly.dev` | Indirizzo su **altra** istanza |

**Regole vincolanti emerse:**

- **Nessuna normalizzazione** tra forme: `mario` **≠** `mario@arkham-im.fly.dev` — stringhe diverse, identità diverse, chat diverse, voci allow list diverse (**per ora**).
- **Case insensitive** in compose/UI; **persistenza sempre lowercase** in DB (vedi § 15.10).
- Entrambe le forme sono **usabili** in compose e allow list.

Il delivery **riconosce** che `@arkham-im.fly.dev` (se è l’`im_server_id` locale) è recapito **interno** — stesso worker, niente Gotham — **senza** fondere le stringhe né unificare le chat.

### 15.3 Inbox — chiave = controparte

Ogni titolare archivio raggruppa per **l’indirizzo della controparte** (chi ho davanti), non il proprio:

- Paolo su Arkham parla con Mario su Blackgate → inbox Paolo: `mario@blackgate-im.fly.dev`; inbox Mario: `paolo@arkham-im.fly.dev`.
- Non esiste una chiave simmetrica condivisa tra i due archivi (modello caselle: due archivi indipendenti).

### 15.4 Identità mittente vista dal destinatario (stessa istanza)

Esempio: Paolo e Mario su `arkham-im.fly.dev`.

| Paolo scrive a | Mario vede mittente come |
|----------------|--------------------------|
| `mario` | `paolo` |
| `mario@arkham-im.fly.dev` | `paolo@arkham-im.fly.dev` |

La forma usata per **indirizzare** la controparte determina come appare l’identità del mittente sul lato destinatario (stessa istanza). Persistenza: `author_address` text lowercase (§ 15.11).

### 15.5 Allow list

- Stessa semantica letterale degli indirizzi: `mario` e `mario@arkham-im.fly.dev` sono **due voci distinte** (per ora).
- Gate inbound/outbound: match su `allowed_address` (lowercase), non su `profiles.id`.
- Schema target: colonna `allowed_address` text — vedi § 15.11. Lo schema attuale (`allowed_profile_id` UUID) e Gotham § 5.4 con split `allowed_profile_id` / `allowed_external_address` sono **pre-chiarimento** e vanno amendati.

### 15.10 Persistenza indirizzi

- Input utente **case insensitive**.
- **Salvataggio sempre in lowercase** (`mario`, `mario@arkham-im.fly.dev`, `paolo@blackgate-im.fly.dev`).
- Nessun altro trattamento (niente equivalenza tra forme, niente `lower()` solo al confronto).

### 15.11 Schema target (solo ciò che prevede il modello chiarito)

Il DB attuale (`peer_profile_id` + `peer_external_address`, allow list su UUID) è **deriva implementativa** — non fa parte del modello documentato in § 15. In amend SYSTEM va **solo** quanto segue (niente colonne parallele «locale vs federato»):

**`messages`**

| Colonna | Tipo | Ruolo |
|---------|------|--------|
| `peer_address` | text NOT NULL | Controparte conversazione — chiave inbox/storico/lettura |
| `author_address` | text NOT NULL | Identità mittente come indirizzo (§ 15.4) |
| `author_id` | uuid nullable | Solo casi tecnici già previsti (es. erogazione gruppo — [SYS-GROUP](../specs/promises/system/SYS-GROUP.md)) |

**Rimuovere** dal modello prodotto: `peer_profile_id`, `peer_external_address` come identità chat. Il delivery può risolvere username → profilo **in transazione** senza persistere UUID come chiave.

**`reception_allowlist`**

| Colonna | Tipo | Ruolo |
|---------|------|--------|
| `archive_user_id` | uuid FK | Chi filtra (invariato) |
| `allowed_address` | text NOT NULL | Indirizzo consentito, lowercase |

**UNIQUE** `(archive_user_id, allowed_address)`. CHECK: `allowed_address` non può coincidere con l’indirizzo del titolare archivio.

**`contacts`** (rubrica — stesso amend, § 16):

| Colonna | Tipo | Ruolo |
|---------|------|--------|
| `archive_user_id` | uuid FK | Titolare archivio (invariato) |
| `address` | text NOT NULL | Indirizzo contatto, lowercase — **unico** dato identitario |

**UNIQUE** `(archive_user_id, address)`. **Rimuovere** dal modello prodotto: `linked_profile_id`, `external_address`, `display_name`, `avatar_url` come persistenza rubrica. Ordinamento lista: per `display_name` restituito da `get_profiles` o per `address` in attesa di risposta.

**Contratti da amendare** (non SSOT finché non promossi): `contracts/schema.md`, `contracts/rpc.md`, Gotham § 5.4, `SYS-MAILBOX`, `SYS-RECEPTION`.

### 15.6 Architettura a tre piani (confermata)

```text
ACCOUNT (client + RPC mittente)
  → «Scrivo a indirizzo X» — nessuna distinzione interno/esterno
  → copia mittente + outbox (sempre)

DELIVERY (worker)
  → unico punto che legge @server e sceglie driver recapito
  → interno: stessa istanza (bare username o @mio_server)
  → Gotham: @altro_server

RECEPTION API (unica)
  → materializza copia in archivio destinatario
  → chiamata da deliver_internal (in-process) e da gateway Gotham (ingress)
```

### 15.7 Gotham — solo indirizzi completi sul wire

- Sul wire **sempre** `user@server` (es. `paolo@arkham-im.fly.dev` → `mario@blackgate-im.fly.dev`): oltre confine istanza, `mario` bare non ha significato.
- Il mittente remoto sul destinatario federato appare sempre come indirizzo completo (da envelope).
- Gotham **non** entra per `mario` bare né per `*@mio_server` quando il delivery classifica l’indirizzo come interno.

### 15.8 Cosa resta della deriva (codice + SDD)

La direttiva originale (address-based, no tipologia chat) resta **ottimale**; il lavoro è riallineare:

| Livello | Azione |
|---------|--------|
| SDD | Amend `PROM-CHAT-PEER-KEY`, `SYS-MAILBOX`, `SYS-RECEPTION`, SURF-CHAT/INBOX, contratti |
| SQL | Schema § 15.11; inbox/storico/lettura/send su `peer_address`; reception API unificata |
| Client | Pipeline su indirizzo (`peer_address`); `get_profiles` batch; rubrica solo address; compose non blocca `user@server` |
| Gotham | Worker outbound/ingress **dopo** modello indirizzo; wire profilo + messaggi; lowercase `user@server` |

### 15.9 Ordine di lavoro (confermato in discussione)

1. Amend SDD + dominio (chiave indirizzo § 15; rubrica + `get_profiles` § 16)
2. Reception API unificata + RPC account su indirizzo
3. Client su indirizzo
4. Allow list per indirizzo
5. Worker Gotham

Implementare Gotham prima del punto 1–3 produce messaggi in DB che inbox/client non possono mostrare.

### 15.12 Recap modello (identità + presentazione)

```text
IDENTITÀ (drift — chiave conversazione)
  peer_address / author_address  →  inbox, chat, allow list, compose

RUBRICA
  contacts.address only  →  elenco indirizzi salvati; nessun snapshot profilo

PRESENTAZIONE (dati pubblici peer)
  get_profiles(addresses[])  →  locale: profiles su stessa istanza
                             →  remoto: interazione federata (§ 16)
  fallback UI                →  stringa indirizzo

VIETATO
  profilo shadow in profiles sul destinatario
  rubrica come cache di nome/avatar
  GET PROFILE singolo come percorso principale (usare batch)
```

---

## 16. Rubrica, `get_profiles` e interazioni federate (2026-09-12)

**Stato:** accordo di modello emerso in chat — da distillare in dominio / SDD `approved`; non SSOT finché non promosso.

### 16.1 Rubrica = solo indirizzo

- La rubrica (`contacts`) salva **soltanto** l’indirizzo dell’account (`address` text lowercase).
- **Non** persiste `display_name`, `avatar_url`, né riferimenti `linked_profile_id` / `external_address` come modello target.
- Aggiungere un contatto = salvare un indirizzo che l’utente vuole ritrovare — **non** copiare il profilo pubblico in rubrica.
- `SYS-CONTACTS` attuale (`display_name` obbligatorio per federati, snapshot per locali) è **deriva** da correggere nello stesso workstream del drift.

### 16.2 Presentazione = `get_profiles` (batch)

I dati profilo pubblici (nome, avatar, pronomi, …) si ottengono con **una sola RPC batch**:

```sql
get_profiles(p_addresses text[]) → setof { address, display_name, avatar_url, … }
```

| Superficie | Uso |
|------------|-----|
| Inbox | `list_inbox` restituisce `peer_address` per riga → client chiama `get_profiles` su tutti gli indirizzi visibili |
| Rubrica | `contacts` elenca indirizzi → `get_profiles` per arricchire la lista |
| Scheda profilo peer | `get_profiles([indirizzo])` — batch da un elemento, **stesso** contratto |
| Header chat / autore gruppo | Stesso servizio |

**Perché plurale:** inbox e rubrica hanno N peer; una batch evita N round-trip e unifica locale/remoto dietro un solo contratto client. Non serve esporre `get_profile` singolo come percorso principale.

**Fallback UI:** finché `get_profiles` non risponde o per indirizzi sconosciuti → mostrare la **stringa indirizzo** (es. `paolo@arkham-im.fly.dev`).

### 16.3 Interazioni federate — profilo come messaggi

I dati profilo di un account su **altra istanza** sono una **interazione federata**: stesso percorso a tre piani (§ 15.6) dei messaggi in ingresso/uscita, **non** un tipo di chat e **non** una riga in `profiles` locale.

```text
ACCOUNT
  Client / RPC: get_profiles(['paolo@arkham-im.fly.dev', …])

DELIVERY
  Per ogni indirizzo: @mio_server → lookup locale su profiles (stessa istanza)
                      @altro_server → richiesta federata (worker Gotham)

RECEPTION (istanza che possiede il profilo)
  Gate (allow list / policy — da definire in amend SYS-RECEPTION)
  Legge profiles sulla propria istanza (fonte autorevole)
  Risponde con snapshot campi pubblici

MATERIALIZZAZIONE lato richiedente
  Risposta a get_profiles — **non** INSERT in profiles
  (cache opzionale con TTL in amend successivo; non è SSOT identità)
```

**Distinzioni:**

| | Messaggio | Profilo pubblico |
|--|-----------|------------------|
| Scopo | Contenuto conversazione | Metadati identità per UI |
| Persistenza locale | Riga `messages` | Solo risposta RPC (eventuale cache) |
| Wire Gotham | `MESSAGE`, `READ`, … | Kind / endpoint dedicato (§ 16.4) — **non** in `gotham.proto` oggi |
| Autorevole | Archivio mittente/destinatario | `profiles` sull’**istanza di origine** dell’indirizzo |

Gotham è **solo trasporto**; la scheda profilo peer locale e remota usa lo **stesso** `get_profiles` lato client.

### 16.4 Scope implementazione

| Fase | Cosa |
|------|------|
| **Drift (passi 1–3)** | Contratto `get_profiles` in SDD; ramo **locale** (stessa istanza); client batch; rubrica solo `address`; overlay per indirizzo |
| **Allow list (passo 4)** | Gate allineato su `allowed_address` |
| **Gotham (passo 5)** | Wire request/response profilo; worker outbound/inbound; ramo federato di `get_profiles` |

Definire il contratto `get_profiles` al passo 1 anche se il ramo federato del delivery arriva al passo 5 — il client non deve cambiare API tra «solo locale» e «federazione live».

### 16.5 Cosa non implica

- La rubrica **non** sostituisce `get_profiles` (non ha dati profilo).
- `get_profiles` **non** crea profilo shadow in `profiles`.
- Inbox **non** deve attendere il batch per mostrare le righe (indirizzo subito, arricchimento async).
- Piggyback profilo dentro ogni `MESSAGE` sul wire resta **ottimizzazione** opzionale — non sostituisce `get_profiles` per rubrica, overlay o peer senza messaggi.

---

## 13. Riferimenti

| Risorsa | Path |
|---------|------|
| Identità chat vincolante | `docs/architecture/mailbox-inbox-outbox-spec.md` |
| ADR no locale/federato | `docs/decisions/no-internal-external-chat-distinction.md` |
| ADR address-based | `docs/decisions/address-based-messaging.md` |
| Promessa chiave chat | `docs/specs/promises/product/PROM-CHAT-PEER-KEY.md` |
| Mailbox SYSTEM | `docs/specs/promises/system/SYS-MAILBOX.md` |
| Wire federazione | `docs/architecture/gotham-protocol.md` |
| Schema | `docs/specs/contracts/schema.md` |
| RPC | `docs/specs/contracts/rpc.md` |
| Istanze demo | `client/deploy/README.md` § Istanze demo |

---

## 14. Istruzioni post-review

1. Leggere e correggere questo file in chat dedicata.
2. Distillare amend SDD / dominio / UML approvati.
3. **Eliminare** `docs/tmp/TEMP-chat-peer-key-address-drift.md` dal repo (non è SSOT).
4. Implementare solo dopo promesse `approved` + conferma scrittura (regola 0 / SDD).

---

*File temporaneo — non fa parte della documentazione canonica (vedi `docs/SSOT.md`).*
