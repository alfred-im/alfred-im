# Messaggistica per indirizzo (username / username@server)

**Data**: 2026-06-27  
**Status**: ✅ Accettata — **regola vincolante**  
**Categoria**: Chat, inbox, rubrica, client, piattaforma  
**Correlata**: [no-internal-external-chat-distinction.md](./no-internal-external-chat-distinction.md), [server-as-reception.md](./server-as-reception.md)

---

## Regola

**Si scrive a un indirizzo. La rubrica non abilita né blocca la messaggistica.**

| Concetto | Ruolo |
|----------|--------|
| **Indirizzo** | Destinatario del messaggio: `username` (Alfred) o `username@server` (esterno) |
| **Messaggi** | **Unica fonte di verità** — `sender_id` + `recipient_profile_id` (o indirizzo esterno) |
| **Inbox** | **Aggregazione derivata on-read** su `messages` (RPC `list_inbox()`), raggruppata per `peer_profile_id` — **nessuna tabella, vista materializzata o cache inbox** |
| **Rubrica (`contacts`)** | Strumento personale opzionale; **isolata** dalle dinamiche di chat |

### Indirizzamento

| Tipo | Formato | Esempio | Stato Alpha |
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

## Modello tecnico

### Inbox = aggregazione on-read (non materializzata)

L’inbox **non** è una tabella né una vista materializzata. È il risultato di una query su `messages` a ogni chiamata:

1. **Fonte di verità**: solo `messages` (+ join `profiles` per il nome)
2. **Calcolo**: `list_inbox()` — `GROUP BY peer_profile_id`, ultimo messaggio, conteggio unread
3. **Indici**: su coppia `(sender_id, recipient_profile_id, created_at)` — sufficienti per Alpha
4. **Realtime**: il client rilegge `list_inbox()` su INSERT in `messages`; nessun trigger che mantenga una cache inbox

Equivalente concettuale: una `VIEW` SQL normale (non `MATERIALIZED`). L’RPC è usata per `security definer`, `auth.uid()` e payload già formattato.

**Perché niente cache inbox**: una tabella con preview/unread duplicati (es. `inbox_threads`) richiede trigger, può divergere da `messages`, e invita FK verso il derivato — antipattern. Se in futuro servisse prestazione, eventuale materializzazione va trattata come **cache** (refresh, nessuna FK, non entità canonica).

### Solo messaggi

| Entità | Ruolo |
|--------|--------|
| `messages` | Fonte di verità |
| `profiles` | Account Alfred |
| `contacts` | Rubrica opzionale |

### RPC

| RPC | Responsabilità |
|-----|----------------|
| `list_inbox()` | Aggregazione on-read: righe inbox da `messages` (preview, unread, ordine per peer) |
| `list_peer_messages(peer_profile_id)` | Storico con un account |
| `mark_peer_read(peer_profile_id)` | Segna letti i messaggi ricevuti da quel peer |
| `send_message_to_profile` | Invio (testo, GIF, voice) |
| `find_profile_by_username` | Risoluzione indirizzo → profilo |

### Trigger `on_message_inserted`

Solo: `delivery_status` interno → `delivered`; federato → `outbox`. **Nessun** upsert inbox.

### Client

- `ChatPeer` — identificato da `profileId`
- `MessagesController` — sempre `peerProfileId`; carica subito (lista vuota se nessun messaggio)
- `HomeScreen` — `_activePeer`; nessuna distinzione bozza/thread
- Realtime inbox: subscribe su `messages` (sender o recipient = io)

---

## Migrazioni

- `20260627200000_address_based_messaging.sql` — `find_profile_by_username`
- `20260627210000_message_centric_messaging.sql` — messaggi peer-based (storico)
- `20260627220000_fix_send_message_to_profile_overload.sql` — PostgREST overload
- `20260627230000_messages_only_inbox.sql` — **drop `inbox_threads`**, RPC peer-only

---

## Riferimenti codice

- Client: `ChatPeer`, `InboxController`, `MessagesController`, `ComposeService`
- Architettura: `docs/architecture/alpha-full-stack.md`
- Implementazione: `docs/implementation/messages-only-inbox.md`
