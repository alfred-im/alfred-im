# Messaggistica per indirizzo (username / username@server)

> **Contratto promessa**: [SYS-MAILBOX.md](../specs/promises/system/SYS-MAILBOX.md) — [SYS-CONTACTS.md](../specs/promises/system/SYS-CONTACTS.md), [PROM-PERSONAL-CONTACTS.md](../specs/promises/product/PROM-PERSONAL-CONTACTS.md), [SURF-CONTACTS.md](../specs/surfaces/SURF-CONTACTS.md). Questo ADR resta vincolante per **indirizzamento** e **isolamento rubrica**; l’archivio messaggi è per-owner (vedi [mailbox-inbox-outbox-spec.md](../architecture/mailbox-inbox-outbox-spec.md)).

**Data**: 2026-06-27  
**Status**: ✅ Accettata — **regola vincolante** (indirizzo + rubrica); schema messaggi → [SYS-MAILBOX](../specs/promises/system/SYS-MAILBOX.md)  
**Categoria**: Chat, inbox, rubrica, client, piattaforma  
**Correlata**: [no-internal-external-chat-distinction.md](./no-internal-external-chat-distinction.md), [server-as-reception.md](./server-as-reception.md)

---

## Regola

**Si scrive a un indirizzo. La rubrica non abilita né blocca la messaggistica.**

| Concetto | Ruolo |
|----------|--------|
| **Indirizzo** | Destinatario del messaggio: `username` (Alfred) o `username@server` (esterno) |
| **Messaggi** | **Archivio per owner** in `messages` (`owner_id`, `author_id`, `peer_profile_id`, `logical_message_id`) — copie correlate per mittente/destinatario |
| **Inbox** | **Aggregazione derivata on-read** sul **mio** archivio (`list_inbox()` WHERE `owner_id = io`), raggruppata per `peer_profile_id` — **nessuna tabella, vista materializzata o cache inbox** |
| **Rubrica (`contacts`)** | Strumento personale opzionale; **isolata** dalle dinamiche di chat |

### Indirizzamento

| Tipo | Formato | Esempio | Stato attuale |
|------|---------|---------|-------------|
| Alfred interno | `username` | `mario_rossi` | ✅ Supportato |
| Esterno federato | `username@server` | `mario@dominio.it` | ⏸ `unsupported` fino ai bridge |

---

## Cosa significa

### ✅ Corretto

- FAB / nuova chat: inserisci indirizzo → apri chat con quel **account** (`profile_id`)
- Chat vuota o con storico: **stessa UI**, stesso identificatore (`peer_profile_id`)
- Primo messaggio: insert in `messages` — la riga compare in inbox al prossimo `list_inbox()` (aggregazione live, non trigger su tabella inbox)
- Messaggio ricevuto da chiunque → compare in inbox **senza** rubrica
- Rubrica: scorciatoia; «Scrivi» apre chat per `profile_id` del contatto

### ❌ Vietato

- Tabella `inbox_threads`, `conversations`, `conversation_participants` o qualsiasi **cache/tabella metadati inbox**
- **FK verso aggregati inbox** (`messages.inbox_thread_id`, `sync_cursors.inbox_thread_id`, ecc.) — un derivato non è entità di dominio
- Vista materializzata inbox con FK che la trattano come fonte di verità
- `thread_id` esposto al client — la chat è `(io, peer_profile_id)`
- Concetti «bozza», «promozione thread», `get_or_create_*`
- Passare da `contact_id` come prerequisito per scrivere (account interni)
- Creare record inbox/conversazione **prima** del primo messaggio (non esiste record inbox; solo messaggi)

---

## Modello tecnico (mailbox — su `main` da PR #159)

### Inbox = aggregazione on-read (non materializzata)

L’inbox **non** è una tabella né una vista materializzata. È il risultato di una query sul **mio archivio** `messages` a ogni chiamata:

1. **Fonte di verità**: `messages` con `owner_id = auth.uid()` (+ join `profiles` per il nome)
2. **Calcolo**: `list_inbox()` — `GROUP BY peer_profile_id`, ultimo messaggio, conteggio unread (`read_at IS NULL` su righe in entrata)
3. **Indici**: su `(owner_id, peer_profile_id, created_at)` — sufficienti per lo scope attuale
4. **Realtime inbox**: subscribe su `messages` con filtro `owner_id = io`; reload `list_inbox()` su INSERT
5. **Realtime chat**: filtro server `owner_id = io`; filtro client `peer_profile_id` (Realtime EQ singola colonna)

Equivalente concettuale: una `VIEW` SQL normale (non `MATERIALIZED`). L’RPC è usata per `security definer`, `auth.uid()` e payload già formattato.

**Perché niente cache inbox**: una tabella con preview/unread duplicati (es. `inbox_threads`) richiede trigger, può divergere da `messages`, e invita FK verso il derivato — antipattern.

### Solo messaggi (+ outbox)

| Entità | Ruolo |
|--------|--------|
| `messages` | Archivio per owner (fonte di verità per inbox e chat) |
| `outbox` | Coda invio — **sempre** (anche internal), consumer RPC o bridge |
| `profiles` | Account Alfred |
| `contacts` | Rubrica opzionale |

### RPC

| RPC | Responsabilità |
|-----|----------------|
| `list_inbox()` | Aggregazione on-read sul mio archivio |
| `list_peer_messages(peer_profile_id)` | Storico nel mio archivio con un peer |
| `mark_peer_read(peer_profile_id)` | `read_at` su entrata + propagazione su copia mittente (λ) |
| `send_message_to_profile` | Outbox + copie mittente/destinatario in transazione |
| `find_profile_by_username` | Risoluzione indirizzo → profilo |

### Spunte

`delivered_at` / `read_at` / `failed_at` su righe dell’archivio — non più enum `delivery_status` né `message_read_receipts`.

### Client

- `ChatPeer` — identificato da `profileId`
- `MessagesController` — sempre `peerProfileId`; carica subito (lista vuota se nessun messaggio)
- `HomeScreen` — `_activePeer`; nessuna distinzione bozza/thread
- Realtime inbox: subscribe su `messages` (`owner_id = io`)

---

## Migrazioni

- `20260627200000_address_based_messaging.sql` — `find_profile_by_username`
- `20260627210000_message_centric_messaging.sql` — messaggi peer-based (storico)
- `20260627220000_fix_send_message_to_profile_overload.sql` — PostgREST overload
- `20260627230000_messages_only_inbox.sql` — drop `inbox_threads` (storico)
- `20260704120000_mailbox_per_owner_archive.sql` — modello caselle (PR #159)

---

## Riferimenti codice

- Client: `ChatPeer`, `InboxController`, `MessagesController`, `ComposeService`
- Architettura: `docs/architecture/full-stack.md`
