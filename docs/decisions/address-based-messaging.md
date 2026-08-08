# Messaggistica per indirizzo (username / username@server)

**Data**: 2026-08-08 (semantica delivery allineata post-#179)  
**Status**: ✅ Accettata — **regola vincolante** (indirizzo + rubrica isolata)  
**Categoria**: Chat, inbox, rubrica, client, piattaforma  
**Correlata**: [no-internal-external-chat-distinction.md](./no-internal-external-chat-distinction.md), [server-as-reception.md](./server-as-reception.md)

### Contratti e architettura

Vedi [SSOT.md](../SSOT.md) — non duplicare RPC/tabelle qui. Riferimenti rapidi:

- [mailbox-inbox-outbox-spec.md](../architecture/mailbox-inbox-outbox-spec.md)
- [contracts/rpc.md](../specs/contracts/rpc.md)
- [registry.md](../specs/registry.md)

---

## Regola (questo ADR)

**Si scrive a un indirizzo. La rubrica non abilita né blocca la messaggistica.**

| Concetto | Ruolo |
|----------|--------|
| **Indirizzo** | Destinatario: `username` (Alfred) o `username@server` (esterno) |
| **Messaggi** | Archivio **per owner** in `messages` — vedi mailbox spec |
| **Inbox** | Aggregazione **on-read** sul mio archivio (`list_inbox()`), raggruppata per `peer_profile_id` — **nessuna tabella inbox** |
| **Rubrica (`contacts`)** | Strumento personale opzionale; **isolata** dalle dinamiche di chat |

### Indirizzamento

| Tipo | Formato | Esempio | Stato attuale |
|------|---------|---------|---------------|
| Alfred interno | `username` | `mario_rossi` | ✅ Supportato |
| Esterno federato | `username@server` | `mario@dominio.it` | ⏸ `unsupported` fino ai bridge |

---

## Cosa significa

### ✅ Corretto

- FAB / nuova chat: inserisci indirizzo → apri chat con quel **account** (`profile_id`)
- Chat vuota o con storico: **stessa UI**, stesso `peer_profile_id`
- Primo messaggio: insert in `messages` → inbox al prossimo `list_inbox()` (aggregazione live)
- Messaggio ricevuto da chiunque → inbox **senza** rubrica
- Rubrica: scorciatoia; «Scrivi» apre chat per `profile_id` del contatto

### ❌ Vietato

- Tabella `inbox_threads`, `conversations`, `conversation_participants` o **cache inbox**
- **FK verso aggregati inbox** (`messages.inbox_thread_id`, ecc.)
- Vista materializzata inbox come fonte di verità
- `thread_id` esposto al client — la chat è `(io, peer_profile_id)`
- Concetti «bozza», «promozione thread», `get_or_create_*`
- `contact_id` come prerequisito per scrivere (account interni)
- Record inbox/conversazione **prima** del primo messaggio

---

## Inbox = aggregazione on-read (non materializzata)

L’inbox **non** è tabella né vista materializzata. È query sul **mio** archivio a ogni `list_inbox()`:

1. Fonte: `messages` WHERE `owner_id = auth.uid()` (+ join `profiles`)
2. Calcolo: `GROUP BY peer_profile_id`, ultimo messaggio, unread (`read_at IS NULL` su entrata)
3. Realtime inbox: subscribe `messages` (`owner_id = io`); reload `list_inbox()` su INSERT
4. Realtime chat: filtro server `owner_id = io`; client `peer_profile_id`

Equivalente: `VIEW` SQL normale (non `MATERIALIZED`). L’RPC serve per `security definer`, `auth.uid()` e payload formattato — dettaglio in [contracts/rpc.md](../specs/contracts/rpc.md#list_inbox).

**Perché niente cache inbox:** preview/unread duplicati divergono da `messages` e invitano FK sul derivato.

---

## Delivery e spunte (post-#179 — sintesi)

Questo ADR **non** definisce RPC né worker. Regola di confine:

| Attore | Può toccare |
|--------|-------------|
| RPC account (`send_message_to_profile`, `mark_peer_read`, …) | **Solo** archivio `owner_id = auth.uid()` + INSERT `outbox` |
| Worker `alfred_delivery` | Materializza copia destinatario, `delivered_at` / `read_at` mittente (via λ), gate allow list |

Flusso internal (un solo posto con diagramma completo): [mailbox-inbox-outbox-spec.md § Consegna](../architecture/mailbox-inbox-outbox-spec.md#consegna--stessa-pipeline-ovunque-vincolante).  
Semantica ✓ / ✓✓ / blu: [server-as-reception.md](./server-as-reception.md).

`delivered_at` / `read_at` / `failed_at` su righe archivio — non enum `delivery_status`.

---

## Client (puntatori)

- Identità chat: `ChatPeer` / `peer_profile_id` — [no-internal-external-chat-distinction](./no-internal-external-chat-distinction.md)
- Multi-account + inbox: [guides/multi-account.md](../guides/multi-account.md)
- Codice: `ComposeService`, `InboxController`, `MessagesController` — [PROJECT_MAP.md](../../PROJECT_MAP.md)

---

## Migrazioni (indirizzo / inbox on-read)

Solo storico **indirizzamento** e drop cache inbox; delivery plane (#159, #179) in mailbox spec e `supabase/migrations/`.

- `20260627200000_address_based_messaging.sql` — `find_profile_by_username`
- `20260627210000_message_centric_messaging.sql` — messaggi peer-based
- `20260627220000_fix_send_message_to_profile_overload.sql` — PostgREST overload
- `20260627230000_messages_only_inbox.sql` — drop `inbox_threads`
- `20260704120000_mailbox_per_owner_archive.sql` — archivio per owner (#159)
- `20260719220000_list_peer_messages_recent_window.sql` — finestra recente + cursore
