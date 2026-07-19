# PROM-CHAT-PEER-KEY — Chiave conversazione per profilo peer

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `PROM-CHAT-PEER-KEY` |
| **Classe** | PRODUCT |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-19 |
| **PR origine** | #159 |

Promessa di prodotto: una chat è identificata da `(io, peer_profile_id)` — nessun `thread_id` esposto; stessa UI con storico vuoto o pieno.

---

## 1. Problema / obiettivo

L'utente apre e naviga conversazioni per **indirizzo peer** (username interno / `profileId`), non per identificatori thread server. La chat esiste come vista sull'archivio owner aggregato per `peer_profile_id`, anche prima del primo messaggio.

---

## 2. Promesse

### MUST

| ID | Promessa |
|----|----------|
| **PROM-CHAT-PEER-KEY-001** | Chat client = `(io, indirizzo peer)` — `username` interno; **nessun** `thread_id` esposto |
| **PROM-CHAT-PEER-KEY-002** | Chiave canonica conversazione 1:1 = identificativo profilo del peer |
| **PROM-CHAT-PEER-KEY-003** | Stessa schermata chat con storico **vuoto** o **pieno** per lo stesso `profileId` |
| **PROM-CHAT-PEER-KEY-004** | Prima riga inbox solo dopo primo messaggio nel mio archivio con quel peer |
| **PROM-CHAT-PEER-KEY-005** | Cambio peer attivo: stato chat reset — nessuna bolla/stato del peer precedente visibile |

### MUST NOT

| ID | Promessa |
|----|----------|
| **PROM-CHAT-PEER-KEY-010** | `thread_id` esposto al client |
| **PROM-CHAT-PEER-KEY-011** | Record inbox/conversazione prima del primo messaggio materializzato |
| **PROM-CHAT-PEER-KEY-012** | Tabella/cache/vista materializzata inbox lato client |

---


## 3. Modello (riferimento)

| Elemento | Artefatto |
|----------|-----------|
| Glossario / comandi | [docs/domain/messaging/](../../../domain/messaging/), [docs/domain/navigation/](../../../domain/navigation/) |
| UML | [docs/model/uml/messaging/](../../model/uml/messaging/), [docs/model/uml/navigation/](../../model/uml/navigation/) |
| Statechart client | [client/lib/machines/messaging/](../../../client/lib/machines/messaging/), [client/lib/machines/navigation/](../../../client/lib/machines/navigation/) |
| Apertura conversazione | `OpenConversation` · [navigation-shell-state.puml](../../model/uml/navigation/navigation-shell-state.puml) |

**Implementazione (non vincolante):** [docs/domain/messaging/README.md](../../../domain/messaging/README.md) · schema: [SYS-MAILBOX](../system/SYS-MAILBOX.md)


## 4. Superfici conformi

| Superficie | Stato | File |
|------------|-------|------|
| SURF-INBOX | `implemented` | [SURF-INBOX.md](../../surfaces/SURF-INBOX.md) |
| Chat 1:1 | `implemented` | `chat_panel.dart`, `messages_controller.dart` |
| Compose nuova chat | `implemented` | `compose_service.dart` |

---

## 5. Tracciabilità

| PROM-ID | Verifica |
|---------|----------|
| PROM-CHAT-PEER-KEY-001, 010 | `mailbox_schema_smoke.sql` — assenza `thread_id` |
| PROM-CHAT-PEER-KEY-002, 003 | `compose_service_test.dart`; `messages_controller` load vuoto |
| PROM-CHAT-PEER-KEY-004 | `mailbox_inbox_smoke.sql` — invio senza rubrica |
| PROM-CHAT-PEER-KEY-005 | `home_screen.dart` — `ValueKey(peer.profileId)` |
| PROM-CHAT-PEER-KEY-012 | `mailbox_schema_smoke.sql` — nessuna cache inbox |


Gate: `bash scripts/check-spec-sync.sh` + `cd client && bash scripts/verify.sh` · `integration` + `e2e-multi`

---

## 6. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [registry.md](../../registry.md) | Indice promesse |
| [SYS-MAILBOX](../system/SYS-MAILBOX.md) | Archivio per owner, aggregazione inbox |
| [PROM-PERSONAL-CONTACTS](./PROM-PERSONAL-CONTACTS.md) | Rubrica non prerequisito |
