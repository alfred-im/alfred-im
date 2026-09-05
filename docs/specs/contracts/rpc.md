# Contratto RPC — messaggistica

**Ultima revisione**: 2026-09-05  
**Status**: `implemented` su `main` (migrazioni fino a `20260905140000`, 58 totali in `supabase/migrations/`)  
**Spec**: [SYS-MAILBOX](../promises/system/SYS-MAILBOX.md), [SYS-GROUP](../promises/system/SYS-GROUP.md), [SYS-CONTACTS](../promises/system/SYS-CONTACTS.md), [SYS-PROFILE](../promises/system/SYS-PROFILE.md), [SYS-RECEPTION](../promises/system/SYS-RECEPTION.md), [SYS-ACCOUNT-BOUNDARY](../promises/system/SYS-ACCOUNT-BOUNDARY.md), [SYS-DELIVERY](../promises/system/SYS-DELIVERY.md), [SYS-PUSH](../promises/system/SYS-PUSH.md) (`implemented`)

Fonte di verità: `supabase/migrations/`. PostgREST espone solo overload **espliciti** — niente ambiguità di firma.

**RPC pubbliche** (client): `SECURITY DEFINER`. **`GRANT EXECUTE` a `authenticated`** per le RPC messaggistica/profilo (revoke da `anon` e `PUBLIC`), salvo eccezione sotto.

**Eccezione registrazione**: `is_username_available` — `GRANT EXECUTE` anche ad **`anon`** (disponibilità username prima del login).

**Helper interni** (`SECURITY DEFINER`): usati solo da altre funzioni SQL — **MUST NOT** `GRANT EXECUTE` a `authenticated` (vedi [Helper interni](#helper-interni-non-api-client)).

---

## `send_message_to_profile`

**Unico punto invio messaggi.**

```sql
send_message_to_profile(
  p_recipient_profile_id uuid,
  p_body text default '',
  p_client_message_id text default null,
  p_content_type message_content_type default 'text',
  p_media_url text default null,
  p_duration_seconds integer default null,
  p_media_mime text default null,
  p_media_size_bytes bigint default null,
  p_latitude double precision default null,
  p_longitude double precision default null
) → messages
```

| `content_type` | Validazione |
|----------------|-------------|
| `text` | `body` trim non vuoto |
| `gif` | `media_url` obbligatorio |
| `voice` | `media_url`, `duration_seconds` > 0, `media_mime` obbligatori |
| `location` | `latitude` ∈ [-90,90], `longitude` ∈ [-180,180] |

Errori comuni: `not authenticated`, `cannot message yourself`, `recipient not found`, `recipient not in reception allowlist`, `empty message`, `unsupported content_type`.

Semantica mailbox ([SYS-ACCOUNT-BOUNDARY](../promises/system/SYS-ACCOUNT-BOUNDARY.md) — RPC account solo confine mittente):

0. Gate **outbound** [SYS-RECEPTION](../promises/system/SYS-RECEPTION.md): destinatario ∈ `reception_allowlist` del mittente? Se **no** → `raise exception 'recipient not in reception allowlist'` (nessuna copia mittente)
1. INSERT copia mittente (`archive_user_id = author_id = auth.uid()`), id logico messaggio (λ) mintato dal **server mittente**, date null
2. INSERT `outbox` (`protocol = internal`, `event_kind = deliver`, `status = queued`)
3. `alfred_delivery.process_outbox` (worker, stessa transazione):
   - **Gate allow list** [SYS-RECEPTION](../promises/system/SYS-RECEPTION.md): mittente ∈ `reception_allowlist` del destinatario?
   - Se **sì**: INSERT copia destinatario; UPDATE mittente `delivered_at = now()`
   - Se **no**: skip copia destinatario; `delivered_at` resta null; outbox `completed` (rifiuto silenzioso)
4. RETURN riga mittente (sempre successo se validazione ok)

Lista allow vuota → passo 3 sempre **no** (nessuno consentito).

Idempotenza: stesso `p_client_message_id` → stessa riga mittente (no duplicati).

**MUST NOT**: promozione `delivered` senza copia destinatario materializzata; errore RPC verso mittente su rifiuto allow list **inbound**; INSERT copia mittente su violazione gate **outbound**; trigger `on_message_inserted` legacy.

**Helper**: `is_sender_allowed_for_reception(archive_user_id, sender_profile_id) → boolean` — migrazione `20260704130000`; **helper interno** (non chiamabile da client).

**Migrazioni**: `20260627210000`, `20260627220000` (drop overload 5-arg), `20260627120100` (voice), `20260702120100` (location), `20260704120000` (mailbox), `20260704130000` (reception allowlist gate), `20260711190000` (delivery plane), `20260905000000` (id logico messaggio solo server mittente).

### Destinatario gruppo (SYS-GROUP)

Se `p_recipient_profile_id` ha `profile_kind = group` — recapito via worker [SYS-DELIVERY](../promises/system/SYS-DELIVERY.md):

1. Stessi passi 1–2 (solo copia mittente umano + outbox)
2. Worker: gate allow list **bidirezionale** mittente ↔ gruppo — due chiamate `is_sender_allowed_for_reception` (gruppo←mittente e mittente←gruppo); **non** usa `is_bidirectional_allowed`
3. Se **sì**: INSERT storico gruppo; `delivered_at` su copia mittente; erogazione automatica verso allow list gruppo
4. Erogazione fallita per singolo partecipante: skip silenzioso; **non** altera `delivered_at` mittente oltre passo 3

Invio con `auth.uid()` = gruppo verso persona: `author_id = gruppo`, **`original_author_id = gruppo`**; gate e recapito come chat private.

### `broadcast_message_to_allowlist` (SYS-GROUP)

Solo account `profile_kind = group`. **Una** riga archivio gruppo + outbox `event_kind = group_erogate` → worker `alfred_delivery.group_erogate`.

```sql
broadcast_message_to_allowlist(
  p_body text default '',
  p_client_message_id text default null,
  p_content_type message_content_type default 'text',
  p_media_url text default null,
  p_duration_seconds integer default null,
  p_media_mime text default null,
  p_media_size_bytes bigint default null,
  p_latitude double precision default null,
  p_longitude double precision default null
) → messages
```

| `content_type` | Validazione |
|----------------|-------------|
| `text` | `body` trim non vuoto |
| `gif` | `media_url` obbligatorio |
| `voice` | `media_url`, `duration_seconds` > 0, `media_mime` obbligatori |
| `location` | `latitude` / `longitude` obbligatori (senza range [-90,90]/[-180,180] come `send_message_to_profile`) |

Errori: `not authenticated`, `only group accounts can broadcast`, `no allow list recipients`, validazione contenuto come tabella sopra.

Idempotenza: stesso `p_client_message_id` → stessa riga archivio gruppo.

**Migrazioni**: `20260706120000`, `20260706140000`, `20260711190000`.

---

## `list_archive_messages`

Storico unico account gruppo (shell senza inbox peer).

```sql
list_archive_messages(
  p_limit integer default 100
) → setof messages
```

Righe WHERE `archive_user_id = auth.uid()` AND contenuto renderizzabile (`mailbox_has_renderable_content`) ORDER BY `created_at` ASC.

Usato da account `profile_kind = group` al posto di `list_peer_messages` — vedi [SYS-GROUP](../promises/system/SYS-GROUP.md) REQ-006/017.

**Migrazioni**: `20260706120000`.

---

## `list_inbox`

Non usato quando `auth.uid()` è account `group` — vedi [SYS-GROUP](../promises/system/SYS-GROUP.md).

```sql
list_inbox() → table (
  protocol contact_protocol,
  display_name text,
  peer_profile_id uuid,
  peer_external_address text,
  peer_avatar_url text,
  peer_cover_url text,
  peer_pronouns text,
  peer_profile_kind profile_kind,
  peer_in_contacts boolean,
  peer_is_allowed boolean,
  last_message_preview text,
  last_message_at timestamptz,
  unread_count integer
)
```

Aggregazione su `messages` WHERE `archive_user_id = auth.uid()`:

- Solo `protocol = 'internal'`, `peer_profile_id IS NOT NULL`, `mailbox_has_renderable_content(body, content_type)`
- `unread_count` = righe **in entrata** (`author_id <> archive_user_id`) con `read_at IS NULL`
- Ordine: `last_message_at` DESC

Preview per tipo: testo troncato, `[GIF]`, `format_voice_preview`, `format_location_preview`.

`peer_in_contacts` / `peer_is_allowed`: relazione viewer↔peer (rubrica internal + `reception_allowlist`).

**Migrazioni**: `20260627230000`, `20260628100000`, aggiornamenti voice/location, `20260704120000`, `20260706130000`, `20260806190000_profile_cover_url.sql`, `20260810120000_peer_relationship_flags.sql`.

---

## `list_peer_messages`

```sql
list_peer_messages(
  p_peer_profile_id uuid,
  p_limit integer default 100,
  p_before_created_at timestamptz default null
) → setof messages
```

Righe WHERE `archive_user_id = auth.uid()` AND `peer_profile_id = p_peer_profile_id` AND `mailbox_has_renderable_content(...)`.

- Senza cursore: **ultimi** `p_limit` messaggi (finestra recente), restituiti in ordine cronologico ASC.
- Con `p_before_created_at`: fino a `p_limit` messaggi con `created_at < p_before_created_at` (pagina più vecchia), ordine ASC.

`LIMIT greatest(1, least(coalesce(p_limit, 100), 500))`.

L'anteprima `list_inbox` per un peer deve cadere nella finestra senza cursore quando esiste storico.

**Migrazioni**: `20260704120000`, `20260719220000_list_peer_messages_recent_window.sql` (SYS-MAILBOX-036/057, SURF-CHAT-015).

---

## `mark_peer_read`

```sql
mark_peer_read(p_peer_profile_id uuid) → void
```

Chiamata dal **destinatario** all’apertura chat con un peer.

Effetti (solo confine lettore — [SYS-ACCOUNT-BOUNDARY](../promises/system/SYS-ACCOUNT-BOUNDARY.md)):

1. UPDATE righe in entrata nel mio archivio (`author_id = peer`, `read_at IS NULL`, contenuto renderizzabile) SET `read_at = now()`, mint `read_receipt_id = gen_random_uuid()` per ogni riga
2. Per ogni λ: INSERT outbox `event_kind = read_receipt` con payload `read_receipt_id`, `reader_id`, `sender_profile_id`, id logico messaggio; **`message_id` = id riga lettore** (copia in entrata) → worker `process_read_receipt` → `read_at` + `read_receipt_id` sulla copia mittente

**Migrazioni**: `20260704120000`, `20260905140000_read_receipt_id.sql`.

---

## `apply_message_reaction`

```sql
apply_message_reaction(p_logical_message_id uuid, p_emoji text) → message_reaction_facts
```

Registra un fatto `applied` su λ. Richiede partecipazione (`messages.archive_user_id = auth.uid()` per quel λ).

- **Percorso**: accoda outbox `event_kind = reaction_fact` (`message_id` = riga messages del reagente) → worker `process_reaction_fact` esegue INSERT append-only; outbox completata con `reaction_fact_id`.
- **Idempotenza**: stessa emoji già attiva → ritorna l'ultimo fatto `applied` senza nuovo accodamento.
- **Cambio emoji**: nuovo fatto `applied`; i fatti precedenti restano nello storico.

**Migrazioni**: `20260807200000_message_reaction_facts.sql`, `20260905120000_reaction_fact_outbox.sql`.

**Spec**: [SYS-MAILBOX](../promises/system/SYS-MAILBOX.md), [SYS-DELIVERY](../promises/system/SYS-DELIVERY.md).

---

## `withdraw_message_reaction`

```sql
withdraw_message_reaction(p_logical_message_id uuid) → message_reaction_facts | null
```

Registra un fatto `withdrawn` su λ. **No-op** (ritorna `null`) se nessuna reaction attiva.

Accoda outbox `event_kind = reaction_fact` (payload `kind = withdrawn`, senza emoji) → worker INSERT append-only.

**Migrazioni**: `20260807200000_message_reaction_facts.sql`, `20260905120000_reaction_fact_outbox.sql`.

---

## `list_message_reactions`

```sql
list_message_reactions(p_logical_message_ids uuid[]) → table (
  logical_message_id uuid,
  emoji text,
  reaction_count bigint,
  reactor_ids uuid[],
  includes_me boolean
)
```

Stato corrente **derivato**: ultimo fatto per `(λ, reactor_id)`; solo `applied` entra nell'aggregato.

Solo λ presenti nel mio archivio (`archive_user_id = auth.uid()`).

---

## `find_profile_by_username`

```sql
find_profile_by_username(p_username text) → table (
  id uuid, username text, display_name text, avatar_url text, cover_url text, pronouns text,
  profile_kind profile_kind,
  peer_in_contacts boolean,
  peer_is_allowed boolean
)
```

Risoluzione indirizzo Alfred interno → profilo pubblico (avatar, cover, pronomi; `profile_kind` per routing shell). Richiede `auth.uid()`; **esclude** il proprio profilo (`p.id <> auth.uid()`).

**Migrazioni**: `20260806190000_profile_cover_url.sql` (`cover_url`); `20260810120000_peer_relationship_flags.sql` (flag relazione viewer).

**Spec**: [SYS-PROFILE](../promises/system/SYS-PROFILE.md).

---

## `get_peer_context`

```sql
get_peer_context(p_peer_profile_id uuid) → table (
  id uuid, username text, display_name text, avatar_url text, cover_url text, pronouns text,
  profile_kind profile_kind,
  peer_in_contacts boolean,
  peer_is_allowed boolean
)
```

Profilo pubblico + flag relazione viewer↔peer. Usato quando il peer non è ancora in `list_inbox()` (push, link, compose). Esclude il proprio profilo.

**Migrazioni**: `20260810120000_peer_relationship_flags.sql`.

**Spec**: [SYS-PROFILE](../promises/system/SYS-PROFILE.md).

---

## `is_username_available`

```sql
is_username_available(p_username text) → boolean
```

Verifica namespace username (registrazione). **`GRANT EXECUTE` a `anon` e `authenticated`**.

**Migrazioni**: `20260625120000`.

---

## `search_profiles`

```sql
search_profiles(p_query text, p_limit integer default 20) → table (
  id uuid, username text, display_name text, avatar_url text,
  peer_in_contacts boolean,
  peer_is_allowed boolean
)
```

Ricerca utenti Alfred per aggiunta contatto internal (min 2 caratteri client). Esclude `auth.uid()`. `p_limit` default 20, **cap 50** in SQL (`least(p_limit, 50)`).

**Spec**: [SYS-CONTACTS](../promises/system/SYS-CONTACTS.md).

---

## Helper interni (non API client)

Funzioni `SECURITY DEFINER` invocate **solo** da worker `alfred_delivery` o altre RPC SQL. **MUST NOT** avere `GRANT EXECUTE` per `authenticated`.

| Funzione | Uso interno | Migrazione |
|----------|-------------|------------|
| `mailbox_has_renderable_content(text, message_content_type)` | Filtro contenuto renderizzabile in inbox/liste | `20260704120000` |
| `format_voice_preview(integer)` | Preview inbox voice | `20260627120100` |
| `format_location_preview()` | Preview inbox location | `20260702120100` |
| `is_sender_allowed_for_reception(uuid, uuid)` | Gate allow list nel worker delivery | `20260704130000` |
| `is_bidirectional_allowed(uuid, uuid, uuid)` | Helper gruppo legacy — **non** invocata dal worker #179 | `20260706120000` |
| `profile_kind_of(uuid)` | Routing `profile_kind` in RPC account | `20260706120000` |
| `alfred_delivery.process_outbox(uuid)` | Dispatcher outbox | `20260711190000` |
| `alfred_delivery.deliver_internal(uuid)` | Recapito 1:1 / verso gruppo | `20260711190000` |
| `alfred_delivery.process_read_receipt(uuid)` | Legge payload outbox → propaga lettura | `20260711190000` |
| `alfred_delivery.propagate_read_receipt(uuid, uuid, uuid)` | UPDATE `read_at` + `read_receipt_id` copia mittente per λ | `20260905140000` |
| `alfred_delivery.process_reaction_fact(uuid)` | INSERT fatto reaction da payload outbox | `20260905120000` |
| `alfred_delivery.process_push_notify(uuid)` | Pipeline Web Push post-recapito | `20260714100000` |
| `alfred_delivery.group_erogate(uuid)` | Broadcast gruppo → allow list | `20260711190000` |
| `alfred_delivery.erogate_group_message(...)` | Fan-out proxy gruppo | `20260711190000` |
| `alfred_delivery.materialize_inbound_sender_message(...)` | Inbound federato: copia destinatario con λ remoto | `20260905000000` |

Revoca `authenticated`: migrazione `20260707190000`. Smoke: `supabase/tests/rpc_helper_security_smoke.sql`.

Spec: SYS-RECEPTION-028, SYS-GROUP-028, SYS-GROUP-027.

---

## Enum `message_content_type`

Valori su `main`: `text`, `gif`, `voice`, `location`, `image`, `video`.

Aggiunta enum in migrazioni separate (commit enum prima dell’uso in RPC).

---

## Smoke test

| File | Verifica |
|------|----------|
| `supabase/tests/schema_smoke.sql` | Assenza `inbox_threads`, `message_read_receipts`; schema mailbox |
| `supabase/tests/mailbox_schema_smoke.sql` | `archive_user_id`, assenza `delivery_status` su `messages` |
| `supabase/tests/delivery_ticks_smoke.sql` | Contratto ✓ / ✓✓ grigie / ✓✓ blu + allow list + outbox `event_kind` |
| `supabase/tests/mailbox_send_smoke.sql` | Invio + `delivered_at` |
| `supabase/tests/mailbox_idempotency_smoke.sql` | Idempotenza `client_message_id` |
| `supabase/tests/mailbox_delivery_smoke.sql` | Copia destinatario + outbox `completed` |
| `supabase/tests/mailbox_read_smoke.sql` | `mark_peer_read` → `read_at` mittente |
| `supabase/tests/mailbox_inbox_smoke.sql` | `list_inbox` + unread |
| `supabase/tests/mailbox_send_media_smoke.sql` | Validazione `gif` / `location` / `image` / `video` |
| `supabase/tests/send_message_to_profile_smoke.sql` | Invio a profilo non in rubrica |
| `supabase/tests/reception_allowlist_schema_smoke.sql` | Tabella + helper gate |
| `supabase/tests/reception_allowlist_gate_smoke.sql` | Rifiuto silenzioso inbound vs recapito allowed |
| `supabase/tests/reception_outbound_gate_smoke.sql` | Errore outbound se destinatario ∉ allow list mittente |
| `supabase/tests/rpc_helper_security_smoke.sql` | Helper interni non eseguibili da `authenticated` |
| `supabase/tests/group_schema_smoke.sql` | `list_archive_messages`, `profile_kind`, `broadcast_message_to_allowlist` |
| `supabase/tests/message_reaction_facts_smoke.sql` | Apply/withdraw/idempotenza/cambio emoji su λ |

Gate client: `verify.sh` + `bash scripts/test.sh integration` + `bash scripts/test.sh e2e-multi`

---

## Client mapping

| RPC | Service Dart |
|-----|--------------|
| `send_message_to_profile` | `PeerMessageService.sendToProfile` |
| `broadcast_message_to_allowlist` | `GroupArchiveService.broadcastToAllowlist` / `broadcastGifToAllowlist` / … |
| `list_inbox` | `InboxService.fetchInbox` |
| `list_peer_messages` | `PeerMessageService.fetchPeerMessages` |
| `list_archive_messages` | `GroupArchiveService.fetchArchiveMessages` |
| `mark_peer_read` | `InboxService.markPeerRead` |
| `apply_message_reaction` | `PeerMessageService.applyReaction` |
| `withdraw_message_reaction` | `PeerMessageService.withdrawReaction` |
| `list_message_reactions` | `PeerMessageService.fetchReactionSummaries` |
| `find_profile_by_username` | `ComposeService` / profile lookup |
| `is_username_available` | Registrazione / validazione username |
| `search_profiles` | `ContactService.searchProfiles` |
| `reception_allowlist` (PostgREST) | `ReceptionAllowlistService` |
| `push_subscriptions` (PostgREST) | `PushSubscriptionService` — [SYS-PUSH](../promises/system/SYS-PUSH.md) |

---

## `push_subscriptions` (PostgREST — SYS-PUSH)

Client autenticato: UPSERT via PostgREST su `push_subscriptions` (RLS `user_id = auth.uid()`).

| Operazione | Quando |
|------------|--------|
| UPSERT `(user_id, device_id, endpoint, keys…)` | Permesso browser `granted`; login; aggiungi account; avvio app |
| DELETE `WHERE user_id AND device_id` | Chiudi account |

**MUST NOT**: client invoca Edge Function `send-push`.

**Spec**: [SYS-PUSH](../promises/system/SYS-PUSH.md), [PROM-PUSH-NOTIFY](../promises/product/PROM-PUSH-NOTIFY.md).

---

## Edge Function `send-push` (SYS-PUSH)

Invocata solo da infrastruttura server (hook delivery / `push_notify` outbox). Non esposta al client.

Input (JSON): `recipient_user_id`, `peer_profile_id`, `peer_display_name`, `preview_text`, `logical_message_id`, `content_type`.

---

## Riferimenti

- [full-stack.md](../../architecture/full-stack.md) §3
- Migrazioni in [`supabase/migrations/`](../../../supabase/migrations/)
