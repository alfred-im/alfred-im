# PROM-CHAT-PEER-KEY — Chiave conversazione per indirizzo peer

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `PROM-CHAT-PEER-KEY` |
| **Classe** | PRODUCT |
| **Status** | `approved` |
| **Ultima revisione** | 2026-09-13 |
| **PR origine** | #159 |
| **Amend** | peer_address — distillazione [TEMP-chat-peer-key-address-drift.md](../../../tmp/TEMP-chat-peer-key-address-drift.md) §7 |

Promessa di prodotto: una chat 1:1 è identificata da `(io, peer_address)` — nessun `thread_id` esposto; stessa UI con storico vuoto o pieno. Nessuna tipologia «chat locale» vs «chat federata» in UI, account, inbox, allow list o RPC.

---

## 1. Problema / obiettivo

L'utente apre e naviga conversazioni per **indirizzo peer** (`username` bare o `user@server`), non per UUID profilo né identificatori thread server. La chat esiste come vista sull'archivio titolare aggregato per `peer_address`, anche prima del primo messaggio.

Presentazione (nome, avatar): batch `get_profiles(addresses[])` — non fa parte della chiave conversazione.

---

## 2. Forme indirizzo e chiave messaggistica

| Input | Significato |
|-------|-------------|
| `mario` | Stessa istanza (bare username) |
| `mario@arkham-im.fly.dev` | Server esplicito (stessa istanza se `@server` = `im_server_id` locale) |
| `mario@blackgate-im.fly.dev` | Altra istanza |

**Regole (chiave `peer_address` / allow list / inbox / storico):**

- **`mario` ≠ `mario@arkham-im.fly.dev`** — identità, chat e voci allow list **distinte**. Regola valida nel modello corrente.
- Input case insensitive; persistenza **sempre lowercase**.
- Entrambe le forme usabili in compose e allow list.
- Delivery: `@mio_server` → recapito interno **senza** fondere stringhe né unificare chat.

### Equivalenza a strati (link vs chiave messaggistica)

Due livelli distinti — non contraddizione:

| Livello | `mario` vs `mario@mio_server` |
|---------|-------------------------------|
| **Link / lookup profilo locale** | Entrambe valide; se `@server` = istanza corrente, stesso profilo — vedi [PROM-SHAREABLE-LINK](./PROM-SHAREABLE-LINK.md) § Equivalenza a strati |
| **Chiave `peer_address` / allow list / inbox / storico** | **Distinte** — stringhe diverse = conversazioni diverse |

Amend esplicito: non unificare i due livelli. Vedi [PROM-SHAREABLE-LINK-002](./PROM-SHAREABLE-LINK.md).

---

## 3. `author_address` (copia mittente)

Sulla **copia locale del mittente**, `author_address` è **sempre** l'identità che fa fede in quella comunicazione — allineata al wire Gotham e a ciò che il destinatario vede.

| Paolo (Arkham) compone verso | `peer_address` (copia Paolo) | `author_address` (copia Paolo) |
|------------------------------|------------------------------|--------------------------------|
| `mario` (stessa istanza) | `mario` | `paolo` |
| `mario@arkham-im.fly.dev` | `mario@arkham-im.fly.dev` | `paolo@arkham-im.fly.dev` |
| `mario@blackgate-im.fly.dev` | `mario@blackgate-im.fly.dev` | `paolo@arkham-im.fly.dev` |

Scrivendo **all'esterno** (controparte con `@server` diverso da `im_server_id` locale), il mittente usa **forma FQDN** sulla propria copia — non `paolo` bare.

Inbound federato: `author_address` = indirizzo completo mittente da envelope (`from_address`).

---

## 4. Promesse

### MUST

| ID | Promessa |
|----|----------|
| **PROM-CHAT-PEER-KEY-001** | Chat client = `(io, peer_address)` — `username` bare o `user@server`; **nessun** `thread_id` esposto |
| **PROM-CHAT-PEER-KEY-002** | Chiave canonica conversazione 1:1 = stringa `peer_address` lowercase — **non** UUID profilo |
| **PROM-CHAT-PEER-KEY-003** | Stessa schermata chat con storico **vuoto** o **pieno** per lo stesso `peer_address` |
| **PROM-CHAT-PEER-KEY-004** | Prima riga inbox solo dopo primo messaggio nel mio archivio con quel `peer_address` |
| **PROM-CHAT-PEER-KEY-005** | Cambio peer attivo: stato chat reset — nessuna bolla/stato del peer precedente visibile |
| **PROM-CHAT-PEER-KEY-006** | Inbox raggruppa per **indirizzo controparte** per titolare archivio (asimmetrico tra archivi) |
| **PROM-CHAT-PEER-KEY-007** | `mario` e `mario@mio_server` = **conversazioni distinte** — nessuna fusione automatica |
| **PROM-CHAT-PEER-KEY-008** | Gruppi come account: chat umano → gruppo usa `peer_address` = indirizzo gruppo (es. `team` o `team@arkham-im.fly.dev` secondo §2) |

### MUST NOT

| ID | Promessa |
|----|----------|
| **PROM-CHAT-PEER-KEY-010** | `thread_id` esposto al client |
| **PROM-CHAT-PEER-KEY-011** | Record inbox/conversazione prima del primo messaggio materializzato |
| **PROM-CHAT-PEER-KEY-012** | Tabella/cache/vista materializzata inbox lato client |
| **PROM-CHAT-PEER-KEY-013** | Tipologia «chat locale» vs «chat federata» in UI, account, inbox, allow list o RPC |
| **PROM-CHAT-PEER-KEY-014** | Profilo shadow in `profiles` per peer remoti |
| **PROM-CHAT-PEER-KEY-015** | UUID profilo (`peer_profile_id`) come chiave conversazione client o RPC account |

---

## 5. Modello (riferimento)

| Elemento | Artefatto |
|----------|-----------|
| Glossario / comandi | [docs/domain/messaging/](../../../domain/messaging/), [docs/domain/navigation/](../../../domain/navigation/) |
| UML | [docs/model/uml/messaging/](../../../model/uml/messaging/), [docs/model/uml/navigation/](../../../model/uml/navigation/) |
| Statechart client | [client/lib/machines/messaging/](../../../../client/lib/machines/messaging/), [client/lib/machines/navigation/](../../../../client/lib/machines/navigation/) |
| Apertura conversazione | `OpenConversation` · [navigation-shell-state.puml](../../../model/uml/navigation/navigation-shell-state.puml) |

**Implementazione (non vincolante):** [docs/domain/messaging/README.md](../../../domain/messaging/README.md) · schema target: [SYS-MAILBOX](../system/SYS-MAILBOX.md) (amend §7.7 TEMP)

---

## 6. Superfici conformi

| Superficie | Stato | File |
|------------|-------|------|
| SURF-INBOX | `approved` | [SURF-INBOX.md](../../surfaces/SURF-INBOX.md) |
| Chat 1:1 | `approved` | `chat_panel.dart`, `messages_controller.dart` |
| Compose nuova chat | `approved` | `compose_service.dart` |

---

## 7. Tracciabilità

| PROM-ID | Verifica |
|---------|----------|
| PROM-CHAT-PEER-KEY-001, 010 | `mailbox_schema_smoke.sql` — assenza `thread_id` |
| PROM-CHAT-PEER-KEY-002, 003, 007 | `compose_service_test.dart`; `messages_controller` load vuoto; scenario federato Arkham ↔ Blackgate |
| PROM-CHAT-PEER-KEY-004 | `mailbox_inbox_smoke.sql` — invio senza rubrica |
| PROM-CHAT-PEER-KEY-005 | `home_screen.dart` — `ValueKey(peer.address)` |
| PROM-CHAT-PEER-KEY-006 | `mailbox_inbox_smoke.sql` — raggruppamento per `peer_address` |
| PROM-CHAT-PEER-KEY-012 | `mailbox_schema_smoke.sql` — nessuna cache inbox |
| PROM-CHAT-PEER-KEY-013, 014, 015 | Review spec + migrazione schema §7.7 TEMP |

Gate: `bash scripts/check-spec-sync.sh` + `cd client && bash scripts/verify.sh` · `integration` + `e2e`

---

## 8. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [registry.md](../../registry.md) | Indice promesse |
| [SYS-MAILBOX](../system/SYS-MAILBOX.md) | Archivio per titolare archivio, aggregazione inbox |
| [PROM-SHAREABLE-LINK](./PROM-SHAREABLE-LINK.md) | Equivalenza a strati link vs chiave messaggistica |
| [PROM-PERSONAL-CONTACTS](./PROM-PERSONAL-CONTACTS.md) | Rubrica non prerequisito |
| [PROM-CONVERSATION-SCOPE](./PROM-CONVERSATION-SCOPE.md) | Scope su `peer_address` |
