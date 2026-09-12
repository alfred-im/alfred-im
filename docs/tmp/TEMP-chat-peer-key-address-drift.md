# TEMP — Deriva chiave conversazione: indirizzo vs `profileId`

**Stato:** bozza temporanea — da eliminare dopo promozione in SDD `approved`  
**Revisione:** 2026-09-12 (terza passata — struttura, audit doc, separazione decisioni / lavoro / domande)  
**Audience:** revisione modello / SDD / implementazione federazione  
**Non è SSOT** — vedi `docs/SSOT.md`. Contenuto da distillare in dominio, promesse e contratti.

---

## 1. Sintesi

**Direttiva vincolante** (già in architettura e ADR): la conversazione 1:1 = `(mio account, indirizzo controparte)` — `username` o `user@server`. Nessuna tipologia «chat locale» vs «chat federata» in UI, account, inbox, allow list o RPC.

**Deriva:** implementazione e promesse `implemented` hanno cristallizzato la chiave su `peer_profile_id` (UUID). Finché ogni peer aveva profilo locale, funzionava senza violare l'esperienza utente. La federazione Arkham ↔ Blackgate espone il disallineamento.

**Correzione:** chiave canonica = **indirizzo** (`peer_address` lowercase). Presentazione peer = **`get_profiles(addresses[])`** (batch, profilo pubblico sempre). Gotham è solo trasporto. Ordine: SDD → reception API → client → allow list → worker Gotham.

---

## 2. Direttiva originale (invariata — fonte di verità)

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
| `PROM-CHAT-PEER-KEY` | `-001` (indirizzo) vs `-002`/`-003` (profileId) — internamente contraddittorio |
| `SYS-MAILBOX` | `-034`–`-038`, `-047`: inbox/storico/lettura/unread su `peer_profile_id` UUID |
| `SYS-MAILBOX-030` | compose federato `unsupported` (coerente v1; da revocare con federazione) |
| `SYS-RECEPTION` | `-002`–`-006`: gate su `allowed_profile_id` UUID |
| `SYS-CONTACTS` | snapshot `display_name`/`avatar_url`, split `linked_profile_id` / `external_address` |

### 3.2 Schema e RPC

- `messages`: split `peer_profile_id` + `peer_external_address`; `author_id NOT NULL`.
- `list_peer_messages(uuid)`, `mark_peer_read(uuid)` — nessun parametro indirizzo.
- `list_inbox()`: SQL filtra `peer_profile_id IS NOT NULL` — righe con solo `peer_external_address` **escluse** (nonostante `contracts/rpc.md` documenti OR).
- Nessun `get_profiles(addresses[])` — solo batch per UUID (`ProfileService.fetchSummariesByIds`).

### 3.3 Client

- `ChatPeer` richiede `ProfileSummary.id`.
- Navigation, scope, realtime, push: chiave `peerProfileId` (UUID).
- `compose_service`: `user@server` → `Indirizzo esterno non ancora supportato`.
- Overlay profilo: solo peer con `profiles.id` locale.

### 3.4 Rubrica e profilo: deriva su snapshot e UUID

Fonte: `SYS-CONTACTS`, `ProfileService.fetchSummariesByIds`

| Aspetto | Stato attuale | Modello target (§7) |
|---------|---------------|---------------------|
| `contacts` locale | `linked_profile_id` + snapshot nome/avatar | Solo `address` lowercase |
| `contacts` federato | `external_address` + `display_name` obbligatorio | Solo `address` |
| Dati profilo in UI | Join `profiles` o campi denormalizzati in rubrica / `list_inbox` | `get_profiles(addresses[])` batch |
| Peer overlay remoto | Assente | Stesso `get_profiles` per qualsiasi indirizzo |

---

## 4. Perché la federazione espone la deriva (non la crea)

Prima: ogni controparte conversabile aveva `profiles.id` locale; UUID come chiave runtime era trasparente.

Dopo: `mario@blackgate-im.fly.dev` non ha `profiles.id` su Arkham → inbox, chat, lettura, push, scope e overlay non funzionano. Wire Gotham e colonne federate in schema esistono; modello account/client no.

La federazione è il test di regressione della direttiva address-based.

---

## 5. Sintomi → causa radice

| Sintomo osservabile | Causa radice |
|---------------------|--------------|
| Compose `user@server` → unsupported | Chiave runtime = profilo locale, non indirizzo |
| Inbox senza chat federate | `list_inbox` GROUP BY / filtro solo `peer_profile_id` |
| `list_peer_messages` inutilizzabile per federato | Parametro solo UUID |
| `mark_peer_read` non applicabile | Assume `author_id` e `peer_profile_id` UUID |
| `ChatPeer` non costruibile per peer remoto | `ProfileSummary.id` obbligatorio |
| Push / navigation / realtime | Pipeline keyed su `peerProfileId` |
| Link `#user@other-server/chat` | Lookup locale (`find_profile_by_username`) |
| Unread count errato su inbound federato (futuro) | `author_id <> archive_user_id` con `author_id` null |
| `PROM-CHAT-PEER-KEY` `implemented` vs federazione | Promessa chiusa sul caso locale |
| Rubrica mostra nome senza `get_profiles` | `contacts` persiste snapshot invece di solo indirizzo |
| Inbox N+1 profili | `list_inbox` join `profiles`; manca batch per indirizzo |
| Overlay profilo remoto assente | Nessun `get_profiles` federato |

---

## 6. Cosa **non** è il problema

- **Gotham wire** (envelope, id federativi, dedup, HTTP ack): coerente per messaggi 1:1 testo/location/read/reaction.
- **Outbox unica** locale/federata: modello mailbox § Consegna allineato.
- Gap media ingest, READ/REACTION outbound, errori outbox — **correlati ma distinti** (§11).

---

## 7. Decisioni di modello (chiuse — review 2026-09-12)

> Emersero in discussione di review documentata in questo TEMP. **Non sono SSOT** finché non promosse in promesse `approved`. **Non** sono domande aperte — vedi §9 solo per ciò che resta da decidere; §10 per la scrittura in SDD.

### 7.1 Principi

1. **Non esiste locale/federato** a livello account, UI, inbox, allow list, RPC — solo stringa indirizzo.
2. **Delivery** è l'unico modulo che legge `@server` e sceglie driver recapito (interno vs Gotham).
3. **Gotham** = trasporto tra server Alfred diversi, non tipo di chat.

### 7.2 Forme indirizzo

| Input utente | Significato |
|--------------|-------------|
| `mario` | Stessa istanza (bare username) |
| `mario@arkham-im.fly.dev` | Server esplicito (stessa istanza se `@server` = `im_server_id` locale) |
| `mario@blackgate-im.fly.dev` | Altra istanza |

**Regole:**

- **`mario` ≠ `mario@arkham-im.fly.dev`** — stringhe diverse, identità diverse, chat diverse, voci allow list distinte (**per ora** — vedi D1, D7).
- Input **case insensitive**; persistenza **sempre lowercase**.
- Entrambe le forme usabili in compose e allow list.
- Delivery: se `@server` = `im_server_id` locale → recapito interno **senza** fondere le stringhe né unificare le chat.

### 7.3 Inbox — chiave = controparte

Ogni titolare archivio raggruppa per **indirizzo controparte** (asimmetrico tra i due archivi).

Esempio Paolo (Arkham) ↔ Mario (Blackgate): inbox Paolo → `mario@blackgate-im.fly.dev`; inbox Mario → `paolo@arkham-im.fly.dev`.

### 7.4 `author_address` (stessa istanza)

Esempio: Paolo e Mario su `arkham-im.fly.dev`.

| Paolo scrive a | Mario vede mittente come |
|----------------|--------------------------|
| `mario` | `paolo` |
| `mario@arkham-im.fly.dev` | `paolo@arkham-im.fly.dev` |

La forma usata per indirizzare la controparte determina l'identità mittente sul destinatario.

### 7.5 Allow list

- Una voce = un `allowed_address` lowercase.
- Gate su indirizzo, non su `profiles.id`.
- `mario` e `mario@arkham-im.fly.dev` = **due voci distinte**.

### 7.6 Schema target (prodotto)

Il DB attuale (`peer_profile_id` + `peer_external_address`, allow list su UUID, rubrica con snapshot) è **deriva implementativa**.

**`messages`**

| Colonna | Tipo | Ruolo |
|---------|------|--------|
| `peer_address` | text NOT NULL | Chiave conversazione — inbox, storico, lettura |
| `author_address` | text NOT NULL | Identità mittente come indirizzo (§7.4) |
| `author_id` | uuid nullable | Solo casi tecnici (es. erogazione gruppo — SYS-GROUP) |

Rimuovere dal modello prodotto `peer_profile_id` e `peer_external_address` come identità chat.

**`reception_allowlist`**

| Colonna | Tipo | Ruolo |
|---------|------|--------|
| `allowed_address` | text NOT NULL | lowercase; UNIQUE `(archive_user_id, allowed_address)` |

**`contacts`**

| Colonna | Tipo | Ruolo |
|---------|------|--------|
| `address` | text NOT NULL | Unico dato identitario; UNIQUE `(archive_user_id, address)` |

Rimuovere: `linked_profile_id`, `external_address`, `display_name`, `avatar_url` come persistenza rubrica.

### 7.7 RPC account

- Parametro unificato **`peer_address` text** — niente UUID come chiave conversazione.
- `list_inbox` raggruppa per `peer_address`; payload include `peer_address` per riga.
- `list_peer_messages` / `mark_peer_read` / send: su `peer_address`.
- Unread: «in entrata» definito con `author_address` / confronto con archivio, non solo `author_id` UUID.

### 7.8 Client — identità e presentazione

- `ChatPeer` costruibile con **indirizzo canonico** senza `profiles.id`.
- **Nessun profilo shadow** in `profiles` per peer remoti.
- **Presentazione:** `get_profiles(addresses[])` → dati pubblici; in attesa o assente → **indirizzo grezzo**. La rubrica **non** fornisce nome/avatar.
- Inbox, rubrica, overlay, header chat: **stesso** batch `get_profiles`.
- Navigation / push / realtime / scope: keyed su `peer_address`, non UUID.

### 7.9 Rubrica = solo indirizzo

- `contacts` salva **soltanto** `address` lowercase.
- Aggiungere un contatto = salvare un indirizzo da ritrovare — **non** copiare il profilo pubblico.

### 7.10 `get_profiles` (batch) e profilo federato

```sql
get_profiles(p_addresses text[]) → setof { address, display_name, avatar_url, … }
```

| Superficie | Uso |
|------------|-----|
| Inbox | `list_inbox` → `peer_address` per riga → batch `get_profiles` |
| Rubrica | elenco indirizzi → batch `get_profiles` |
| Scheda profilo peer | `get_profiles([indirizzo])` — stesso contratto |
| Header chat | Stesso servizio |

Profilo remoto = **interazione federata** (stesso percorso a tre piani dei messaggi): risposta RPC, **non** INSERT in `profiles` locale. Wire Gotham per profilo: kind/endpoint dedicato (non in `gotham.proto` oggi) — implementazione al passo 5.

Inbox **non** attende il batch per mostrare le righe (indirizzo subito, arricchimento async).

### 7.11 Profilo pubblico — sempre (consent-first)

- `get_profiles` **non** è gated da allow list né da «aver già chattato».
- L'allow list governa il **recapito messaggi**, non la visibilità del profilo pubblico.
- L'utente è responsabile di non mettere dati sensibili in campi pubblici (`display_name`, avatar, pronomi).
- Federazione: l'istanza di origine serve il profilo su richiesta federata **senza** gate allow list del richiedente.

### 7.12 Architettura a tre piani

```text
ACCOUNT (client + RPC)
  → scrivo a indirizzo X / get_profiles([…])
  → copia mittente + outbox (messaggi)

DELIVERY (worker)
  → legge @server → driver interno o Gotham

RECEPTION API (unica)
  → materializza copia destinatario (messaggi)
  → serve profilo pubblico (lookup locale o risposta federata)
```

### 7.13 Gotham sul wire

- Oltre confine istanza: sempre `user@server` completo.
- Mittente remoto sul destinatario federato: sempre indirizzo completo da envelope.

### 7.14 Ordine di lavoro

1. Amend SDD + dominio (chiave indirizzo + rubrica + `get_profiles`)
2. Reception API unificata + RPC account su indirizzo
3. Client su indirizzo + batch `get_profiles` (ramo locale)
4. Allow list per indirizzo
5. Worker Gotham (messaggi + ramo federato `get_profiles`)

Implementare Gotham prima dei punti 1–3 produce messaggi in DB che inbox/client non possono mostrare.

### 7.15 Recap

```text
IDENTITÀ
  peer_address / author_address  →  inbox, chat, allow list, compose

RUBRICA
  contacts.address only

PRESENTAZIONE
  get_profiles(addresses[])  →  locale o federato; sempre pubblico
  fallback UI                →  stringa indirizzo

VIETATO
  profilo shadow in profiles sul destinatario
  rubrica come cache nome/avatar
  get_profile singolo come percorso principale
  get_profiles gated da allow list
```

---

## 8. Audit documentazione (tensioni verificate 2026-09-12)

| Documento | Stato vs §7 | Azione |
|-----------|-------------|--------|
| `mailbox-inbox-outbox-spec.md` § Identità chat | Allineato | — |
| `mailbox-inbox-outbox-spec.md` tabella «Modello attuale» | Deriva (`peer_profile_id`) | Amend |
| `address-based-messaging.md` | Deriva (GROUP BY `peer_profile_id`) | Amend ADR |
| `no-internal-external-chat-distinction.md` | Parziale (due colonne routing) | Amend |
| `PROM-CHAT-PEER-KEY` | Contraddittorio | Amend |
| `SYS-MAILBOX` | UUID-centric | Amend |
| `SYS-RECEPTION` | `allowed_profile_id` | Amend |
| `SYS-CONTACTS` | Snapshot + split colonne | Amend (stesso workstream) |
| `SYS-PROFILE` | Batch UUID; niente `get_profiles` per indirizzo | Amend |
| `SYS-GROUP` | `peer_profile_id` ovunque | Chiarire — D2 |
| `PROM-PEER-PROFILE` | Solo profilo locale | Amend |
| `PROM-SHAREABLE-LINK-002` | Equivalenza forme | Tensione §7.2 — D1 |
| `PROM-SHAREABLE-LINK-006` | 404 se non risolvibile locale | Amend — D5 |
| `PROM-CONVERSATION-SCOPE` | `peer_profile_id` in scope | Amend |
| `contracts/schema.md` | Split colonne, `author_id NOT NULL` | Amend |
| `contracts/rpc.md` | UUID; `list_inbox` OR non implementato | Amend + SQL |
| `contracts/push-payload.md` | `peerProfileId` UUID | Amend — D6 |
| `gotham-protocol.md` §5.4 | Split colonne pre-§7.6 | Amend |
| `domain/messaging/`, `navigation/`, `contacts/`, `federation/`, `profile/` | Terminologia UUID / snapshot | Amend |
| `PROJECT_MAP.md` | `peer_profile_id` come chiave | Amend post-SDD |
| SQL `list_inbox()` | Solo `peer_profile_id IS NOT NULL` | Migrazione |
| Client | UUID-centric, niente `get_profiles` per indirizzo | Implementazione |

---

## 9. Domande aperte

Solo decisioni **non ancora prese**. Tutto il resto è in §7 (chiuso) o §10 (lavoro da fare, inclusa formalizzazione SDD).

### D1 — Equivalenza `username` vs `username@mio_server`

- **§7.2:** `mario` ≠ `mario@arkham-im.fly.dev` per chat, allow list, inbox.
- **`PROM-SHAREABLE-LINK-002` (`implemented`):** «nessuna distinzione semantica»; test `shareable_link_test.dart` tratta le forme come stesso peer locale.

Serve regola unica. Opzioni: **(A)** equivalenza solo in share/link/profilo locale, chiave messaggistica distinta; **(B)** equivalenza ovunque; **(C)** equivalenza al lookup profilo locale, storico per `peer_address` letterale.

### D2 — Gruppi (`SYS-GROUP`)

`SYS-GROUP` usa `peer_profile_id` per erogazione, inbox verso gruppo, broadcast (`peer_profile_id = NULL` su broadcast gruppo).

I gruppi seguono `peer_address` = username gruppo, o restano eccezione UUID?

### D3 — Migrazione dati esistenti

Backfill `peer_address` da `profiles.username` per righe con `peer_profile_id`?

Storico con `mario` e `mario@arkham` verso lo stesso profilo: due conversazioni distinte (coerente §7.2) o fusione?

### D4 — `author_address` sul percorso federato

Su copia mittente locale verso `mario@blackgate`: `author_address` = `paolo` o `paolo@arkham-im.fly.dev`?

Regola per cross-istanza: da definire esplicitamente (§7.4 copre solo stessa istanza).

### D5 — Link e scheda profilo per indirizzo solo federato

`PROM-SHAREABLE-LINK-006` oggi: 404 se lookup locale fallisce.

Con §7.10–7.11: `#mario@blackgate/chat` su Arkham deve aprire chat/overlay via `get_profiles` (indirizzo + arricchimento async), **non** 404 — anche prima del passo 5 Gotham? Confermare comportamento pre-federazione live.

### D6 — Push e deep link

Migrare payload da `peerProfileId` a `peerAddress`: breaking change su SW installati, o periodo dual-read?

### D7 — «Per ora» su identità distinte (§7.2)

`mario` ≠ `mario@mio_server` è vincolo permanente o unificazione futura pianificata?

---

## 10. Lavoro da fare (non sono domande aperte)

### 10.1 Formalizzazione SDD e dominio

Scrivere in promesse `approved` e dominio tutto ciò che è in §7, incluso:

- `PROM-CHAT-PEER-KEY`, `SYS-MAILBOX`, `SYS-RECEPTION`, `SYS-CONTACTS`, `SYS-PROFILE`
- `PROM-PEER-PROFILE`, `PROM-CONVERSATION-SCOPE`, `PROM-SHAREABLE-LINK`
- SURF-CHAT, SURF-INBOX, SURF-CONTACTS, SURF-PEER-PROFILE
- `contracts/schema.md`, `contracts/rpc.md`, `contracts/push-payload.md`
- `gotham-protocol.md` §5.4
- Dominio: messaging, navigation, contacts, federation, profile, reception
- `registry.md`

### 10.2 Implementazione (dopo `approved`)

| Livello | Azione |
|---------|--------|
| SQL | Schema §7.6; inbox/storico/lettura/send su `peer_address`; `get_profiles`; reception API |
| Client | Pipeline su `peer_address`; batch `get_profiles`; rubrica solo `address` |
| Gotham | Passo 5 — messaggi + profilo federato |

### 10.3 File codice

**Client:** `chat_peer.dart`, `profile_summary.dart`, `compose_service.dart`, `compose_address.dart`, `navigation_coordinator.dart`, `conversation_scope_guard.dart`, `mailbox_message_filter.dart`, `push_web.dart`, `push_deep_link.dart`, `peer_message_service.dart`, `profile_service.dart`, `contact_service.dart`, `machines/navigation/`, `machines/messaging/`, `peer_profile_overlay.dart`, `contacts_screen.dart`, `inbox_panel.dart`, test correlati.

**Supabase:** `list_inbox`, `list_peer_messages`, `mark_peer_read`, send su `peer_address`, `get_profiles(p_addresses text[])`, reception API unificata, migrazione schema §7.6.

### 10.4 Post-merge

Eliminare questo file TEMP.

---

## 11. Gap correlati (scope distinto)

1. Reception allow list su schema attuale (solo UUID)
2. READ/REACTION outbound Gotham
3. Media ingest federato
4. Errori outbox federato (4xx/5xx, `failed_at`)
5. `SYS-FEDERATION-*` in backlog
6. Wire Gotham per `get_profiles` (kind/endpoint — §7.10)

Prerequisito comune: chiave indirizzo (§7). Contratto `get_profiles` va definito al passo 1 anche se il ramo federato arriva al passo 5.

---

## 12. Scenario demo Arkham ↔ Blackgate

1. A su Arkham aggiunge `b@blackgate-im.fly.dev` in allow list.
2. B su Blackgate aggiunge `a@arkham-im.fly.dev` in allow list.
3. A compone `b@blackgate-im.fly.dev` → stessa UI chat locale.
4. Invio → copia mittente `peer_address`; outbox; Gotham.
5. B riceve → `peer_address` = `a@arkham-im.fly.dev`, `author_address` valorizzato.
6. Inbox B mostra riga; `get_profiles` arricchisce nome/avatar di A (passo 5) o mostra indirizzo grezzo.
7. B apre chat → `mark_peer_read` → READ federato → A ✓✓ blu.

Oggi 3–7 falliscono (deriva chiave + reception/schema incompleti).

---

## 13. Riferimenti

| Risorsa | Path |
|---------|------|
| Identità chat | `docs/architecture/mailbox-inbox-outbox-spec.md` |
| ADR | `docs/decisions/address-based-messaging.md`, `no-internal-external-chat-distinction.md` |
| Promesse | `PROM-CHAT-PEER-KEY`, `SYS-MAILBOX`, `SYS-RECEPTION`, `SYS-CONTACTS`, `SYS-PROFILE`, `PROM-PEER-PROFILE` |
| Federazione | `docs/architecture/gotham-protocol.md` |
| Contratti | `docs/specs/contracts/schema.md`, `rpc.md`, `push-payload.md` |
| Istanze demo | `client/deploy/README.md` § Istanze demo |

---

## 14. Istruzioni post-review

1. Risolvere §9 (domande aperte).
2. Distillare §7 in dominio + SDD `approved` (§10.1).
3. Eliminare questo file.
4. Implementare solo dopo `approved` + conferma scrittura (regola 0 / SDD).

---

*File temporaneo — non fa parte della documentazione canonica (vedi `docs/SSOT.md`).*
