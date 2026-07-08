# PROM-CHAT-PEER-KEY — Chiave conversazione per profilo peer

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `PROM-CHAT-PEER-KEY` |
| **Classe** | PRODUCT |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-08 |
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
| **PROM-CHAT-PEER-KEY-002** | Modello UI `ChatPeer.profileId` — chiave canonica conversazione 1:1 |
| **PROM-CHAT-PEER-KEY-003** | Stessa schermata chat con storico **vuoto** o **pieno** per lo stesso `profileId` |
| **PROM-CHAT-PEER-KEY-004** | Prima riga inbox solo dopo primo messaggio nel mio archivio con quel peer |
| **PROM-CHAT-PEER-KEY-005** | `HomeScreen`: `_activePeer`; `ValueKey(peer.profileId)` su pannello messaggi per reset stato al cambio peer |

### MUST NOT

| ID | Promessa |
|----|----------|
| **PROM-CHAT-PEER-KEY-010** | `thread_id` esposto al client |
| **PROM-CHAT-PEER-KEY-011** | Record inbox/conversazione prima del primo messaggio materializzato |
| **PROM-CHAT-PEER-KEY-012** | Tabella/cache/vista materializzata inbox lato client |

---

## 4. Contratto implementativo

| Elemento | Responsabilità |
|----------|----------------|
| `ChatPeer` | `profileId`, `displayName`, identità da [PROM-PROFILE-IDENTITY](./PROM-PROFILE-IDENTITY.md) |
| `MessagesController` | `peerProfileId`; `load()` anche lista vuota |
| `ComposeService` | Risoluzione username → `ChatPeer` via `find_profile_by_username` |
| `HomeScreen` | `_activePeer`; binding chat panel |
| `list_peer_messages(peer)` | Storico WHERE `owner_id = io` AND `peer_profile_id = peer` |

### Semantica «inbox»

L'inbox è **organizzazione UI** della chat: messaggi inviati e ricevuti convivono in `messages` con `owner_id = io`, raggruppati per `peer_profile_id`.

---

## 5. Superfici conformi

| Superficie | Stato | File |
|------------|-------|------|
| SURF-INBOX | `implemented` | [SURF-INBOX.md](../../surfaces/SURF-INBOX.md) |
| Chat 1:1 | `implemented` | `chat_panel.dart`, `messages_controller.dart` |
| Compose nuova chat | `implemented` | `compose_service.dart` |

---

## 6. Tracciabilità

| PROM-ID | Verifica |
|---------|----------|
| PROM-CHAT-PEER-KEY-001, 010 | `mailbox_schema_smoke.sql` — assenza `thread_id` |
| PROM-CHAT-PEER-KEY-002, 003 | `compose_service_test.dart`; `messages_controller` load vuoto |
| PROM-CHAT-PEER-KEY-004 | `mailbox_inbox_smoke.sql` — invio senza rubrica |
| PROM-CHAT-PEER-KEY-005 | `home_screen.dart` — `ValueKey(peer.profileId)` |
| PROM-CHAT-PEER-KEY-012 | `mailbox_schema_smoke.sql` — nessuna cache inbox |


Gate: `bash scripts/check-spec-sync.sh` + `cd client && bash scripts/verify.sh` · `integration` + `e2e-multi`

---

## 7. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [registry.md](../../registry.md) | Indice promesse |
| [SYS-MAILBOX](../system/SYS-MAILBOX.md) | Archivio per owner, aggregazione inbox |
| [PROM-PERSONAL-CONTACTS](./PROM-PERSONAL-CONTACTS.md) | Rubrica non prerequisito |
