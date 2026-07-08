# SYS-GROUP — Account gruppo, partecipazione ed erogazione

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `SYS-GROUP` |
| **Classe** | SYSTEM |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-08 |
| **ADR** | [address-based-messaging.md](../../../decisions/address-based-messaging.md), [mailbox-inbox-outbox-spec.md](../../../architecture/mailbox-inbox-outbox-spec.md), [server-as-reception.md](../../../decisions/server-as-reception.md) |
| **PR origine** | #162 |
| **Correlata** | [SYS-MAILBOX](./SYS-MAILBOX.md), [SYS-RECEPTION](./SYS-RECEPTION.md), [SYS-PROFILE](./SYS-PROFILE.md) |

Promessa SYSTEM — account Alfred `profile_kind = group`, partecipazione solo via `reception_allowlist` bidirezionale, recapito/erogazione automatica su archivio mailbox. Il dettaglio canonico di schema e RPC resta nei contratti.

**Dettaglio canonico**: [contracts/schema.md](../../contracts/schema.md) § gruppi · [contracts/rpc.md](../../contracts/rpc.md) § gruppi / mailbox

---

## 1. Problema / obiettivo

Un **gruppo** è un'identità Alfred (`@famiglia`) con account proprio (GoTrue + profilo). I partecipanti interagiscono come con qualsiasi peer; **partecipazione** ≡ consenso bidirezionale su `reception_allowlist` — nessuna membership separata. Recapito verso/da gruppo e erogazione automatica verso allow list del gruppo nella stessa transazione RPC di [SYS-MAILBOX](./SYS-MAILBOX.md) SEND.

Requisiti **client/UI** (shell senza inbox, registrazione toggle tipo account, badge manifest, attribuzione autore in bolla, realtime subscribe) sono delegati a promesse **PRODUCT** / **SURFACE** — vedi §6.

---

## 2. Promesse backend

### SCHEMA — profilo gruppo e vincoli piattaforma

#### MUST

| ID | Promessa |
|----|----------|
| **SYS-GROUP-001** | Enum `profile_kind`: `user` \| `group` su `profiles`; default `user` per righe esistenti |
| **SYS-GROUP-002** | Username gruppo: stesso namespace e regex di [SYS-PROFILE](./SYS-PROFILE.md) — univoco case-insensitive tra **tutti** i profili |
| **SYS-GROUP-003** | Creazione gruppo = registrazione GoTrue con `profile_kind = group` in `raw_user_meta_data` (o equivalente backend); trigger `handle_new_user` crea profilo coerente |
| **SYS-GROUP-004** | **Nessuna** tabella `group_members`, `group_invitations`, RPC invito/accettazione |
| **SYS-GROUP-005** | `find_profile_by_username` ritorna anche `profile_kind` (o campo equivalente) per routing client |
| **SYS-GROUP-006** | Ogni gruppo = un account distinto (`profiles.id` = `auth.users.id`) |

#### SHOULD

| ID | Promessa |
|----|----------|
| **SYS-GROUP-007** | Vista storico gruppo: messaggi ordinati per `created_at` su archivio `owner_id = gruppo` |

#### MUST NOT

| ID | Promessa |
|----|----------|
| **SYS-GROUP-008** | Email sintetiche GoTrue (`alfred.*@gmail.com`, `@users.alfred.*`) per account gruppo |
| **SYS-GROUP-009** | Tabella membership o cache partecipanti oltre `reception_allowlist` |
| **SYS-GROUP-010** | `GRANT EXECUTE` su helper interni gruppo (`is_bidirectional_allowed`, `profile_kind_of`) al ruolo `authenticated` |

---

### PARTICIPATION — allow list bidirezionale

#### MUST

| ID | Promessa |
|----|----------|
| **SYS-GROUP-011** | Partecipazione effettiva ⇔ `reception_allowlist(owner_id = gruppo, allowed_profile_id = persona)` **e** `reception_allowlist(owner_id = persona, allowed_profile_id = gruppo)` |
| **SYS-GROUP-012** | **Nessuna** «iscrizione al gruppo» — nessun RPC join/leave; aprire chat con `@gruppo` = compose verso profilo come peer |

#### MUST NOT

| ID | Promessa |
|----|----------|
| **SYS-GROUP-013** | Flusso «richiedi di entrare nel gruppo» o conferma invito |
| **SYS-GROUP-014** | Rubrica (`contacts`) come prerequisito backend per partecipare o scrivere al gruppo |

---

### DELIVERY — recapito, erogazione, autori

#### MUST

| ID | Promessa |
|----|----------|
| **SYS-GROUP-015** | Invio verso gruppo: stesso RPC `send_message_to_profile(p_recipient_profile_id)` quando destinatario ha `profile_kind = group` |
| **SYS-GROUP-016** | Pipeline invariata fino al gate allow list: copia mittente umano, outbox, λ ([SYS-MAILBOX](./SYS-MAILBOX.md) SEND) |
| **SYS-GROUP-017** | Gate recapito umano→gruppo: mittente umano ∈ `reception_allowlist` del **gruppo** **e** gruppo ∈ allow list del **mittente** |
| **SYS-GROUP-018** | Su recapito al gruppo: INSERT riga archivio gruppo (`owner_id = gruppo`); `author_id = mittente umano`; `peer_profile_id = mittente umano`; **`original_author_id = mittente umano`** |
| **SYS-GROUP-019** | Su recapito al gruppo: UPDATE copia mittente umano `delivered_at = now()` (✓✓ = **gruppo ha ricevuto**) |
| **SYS-GROUP-020** | **Erogazione automatica**: nella **stessa transazione** dopo INSERT storico gruppo, per ogni `allowed_profile_id` in `reception_allowlist(owner_id = gruppo)` tentare recapito verso quella persona |
| **SYS-GROUP-021** | Gate erogazione gruppo→persona: gruppo come mittente tecnico ∈ allow list della **persona**; persona ∈ allow list del **gruppo** (bidirezionale) |
| **SYS-GROUP-022** | Riga erogata su archivio persona: `owner_id = persona`; `author_id = gruppo`; `original_author_id = mittente umano originale`; `peer_profile_id = gruppo`; stesso λ della catena |
| **SYS-GROUP-023** | Gruppo broadcast: **una** riga archivio gruppo (`owner_id = gruppo`, `author_id = gruppo`, **`original_author_id = gruppo`**, `peer_profile_id = NULL`, un λ); distribuzione proxy verso allow list nella **stessa transazione** |
| **SYS-GROUP-024** | Copie membri da broadcast: `author_id = gruppo`, **`original_author_id = gruppo`**, `peer_profile_id = gruppo`, stesso λ |
| **SYS-GROUP-025** | Erogazione verso persona che **non** passa il gate: skip silenzioso; **non** aggiorna spunte del messaggio originale |
| **SYS-GROUP-026** | Spunte messaggio **originale** (umano→gruppo): solo ✓ accettato e ✓✓ **recapitato al gruppo**; erogazione verso altri partecipanti **non** modifica `delivered_at` / `read_at` della copia del mittente originale |
| **SYS-GROUP-027** | Rimozione allow list: messaggi già in archivio **restano**; solo recapiti **nuovi** bloccati — [SYS-RECEPTION](./SYS-RECEPTION.md) |
| **SYS-GROUP-028** | Colonna `messages.original_author_id` uuid nullable FK → `profiles` — **autore contenuto**; valorizzata in tutti i flussi gruppo |
| **SYS-GROUP-029** | Idempotenza erogazione: UNIQUE `(owner_id, logical_message_id)` per ogni destinatario erogato ([SYS-MAILBOX-005](./SYS-MAILBOX.md)) |
| **SYS-GROUP-030** | Account `user`: `list_inbox()` e `list_peer_messages(gruppo)` includono messaggi erogati con `peer_profile_id = gruppo` |
| **SYS-GROUP-031** | Account `group`: storico via query su `messages` WHERE `owner_id = auth.uid()` ORDER BY `created_at` (non `list_inbox`) |
| **SYS-GROUP-032** | Spunte messaggio **erogato** (su archivio persona): semantica [SYS-MAILBOX](./SYS-MAILBOX.md) READ tra persona e peer **gruppo** — indipendenti dal mittente umano originale |

#### SHOULD

| ID | Promessa |
|----|----------|
| **SYS-GROUP-033** | Preview inbox per messaggio erogato: prefisso o formato che indica autore umano se `original_author_id` valorizzato |

#### MUST NOT

| ID | Promessa |
|----|----------|
| **SYS-GROUP-034** | Aggiornare `delivered_at` del mittente umano originale quando erogazione verso **terzi** riesce o fallisce |
| **SYS-GROUP-035** | Erogazione manuale / «inoltra» in v1 — sempre automatica su recapito al gruppo |
| **SYS-GROUP-036** | Tabella membership per decidere target erogazione — **solo** `reception_allowlist` del gruppo |
| **SYS-GROUP-037** | `author_id = umano` su righe erogate verso partecipanti (mittente tecnico deve essere gruppo) |
| **SYS-GROUP-038** | Esporre al mittente umano quali partecipanti hanno ricevuto l'erogazione |
| **SYS-GROUP-039** | Retro-recapito erogazione dopo aggiunta tardiva ad allow list |
| **SYS-GROUP-040** | `GRANT EXECUTE` su `erogate_group_message` al ruolo `authenticated` — helper solo per RPC `SECURITY DEFINER` interne |

---

## 3. Semantica autori (contratto)

`original_author_id` = **chi ha scritto il contenuto** (campo canonico). Valorizzato **sempre** nei flussi gruppo.

| Situazione | `author_id` | `original_author_id` | `peer_profile_id` (archivio persona) |
|------------|-------------|----------------------|--------------------------------------|
| Umano invia a gruppo (copia umano) | umano | **umano** | gruppo |
| Stesso messaggio su storico gruppo | umano | **umano** | umano |
| Erogazione verso persona | **gruppo** | **umano** | **gruppo** |
| Gruppo broadcast (storico gruppo) | **gruppo** | **gruppo** | NULL |
| Copia membro da broadcast | **gruppo** | **gruppo** | **gruppo** |
| Chat private user↔user | umano | NULL | controparte |

### Flusso umano → gruppo → erogazione (transazione RPC)

```
send_message_to_profile(destinatario = G, G.profile_kind = group)
  → INSERT copia mittente U (author=U, peer=G, λ)
  → outbox
  → SE gate allow U↔G:
       INSERT storico gruppo (owner=G, author=U, original_author=U, peer=U, λ)
       UPDATE copia U delivered_at = now()
       PER OGNI P in reception_allowlist(owner=G):
         SE gate allow G↔P:
           INSERT erogazione (owner=P, author=G, original_author=U, peer=G, λ)
         ALTRIMENTI skip silenzioso
     ALTRIMENTI:
       delivered_at null su copia U
  → RETURN copia U
```

### Flusso gruppo broadcast

```
broadcast_message_to_allowlist()
  → INSERT unica riga storico gruppo (owner=G, author=G, original_author=G, peer=NULL, λ)
  → PER OGNI P in reception_allowlist(owner=G), P ≠ G:
       SE gate allow G↔P:
         INSERT copia membro (owner=P, author=G, original_author=G, peer=G, λ)
  → RETURN riga gruppo
```

---

## 5. Implementazione contratto

| Elemento | Documento / codice |
|----------|-------------------|
| `profiles.profile_kind`, `messages.original_author_id` | [contracts/schema.md](../../contracts/schema.md) § gruppi |
| `send_message_to_profile` (branch gruppo), `broadcast_message_to_allowlist`, helper `erogate_group_message` | [contracts/rpc.md](../../contracts/rpc.md) |
| Gate bidirezionale | `is_bidirectional_allowed` (SECURITY DEFINER, no GRANT authenticated) |
| Migrazioni gruppo | `supabase/migrations/*group*` |
| Smoke SQL | `supabase/tests/group_schema_smoke.sql`, `group_delivery_smoke.sql`, `group_broadcast_smoke.sql`, `rpc_helper_security_smoke.sql` |

---

## 7. Tracciabilità

| SYS-ID | Verifica |
|--------|----------|
| SYS-GROUP-001–003, 028 | `supabase/tests/group_schema_smoke.sql` |
| SYS-GROUP-005 | `group_schema_smoke.sql` + `find_profile_by_username` client |
| SYS-GROUP-010, 040 | `supabase/tests/rpc_helper_security_smoke.sql` |
| SYS-GROUP-011 | `supabase/tests/group_delivery_smoke.sql` (gate bidirezionale) |
| SYS-GROUP-015–022, 025–027, 034 | `supabase/tests/group_delivery_smoke.sql` |
| SYS-GROUP-023, 024 | `supabase/tests/group_broadcast_smoke.sql` |
| SYS-GROUP-032 | [SYS-MAILBOX](./SYS-MAILBOX.md) — `mailbox_read_smoke.sql` |
| PROM-GROUP-AUTHOR-DISPLAY, SURF-GROUP-CONVERSATION-001 | `client/test/unit/group_message_display_test.dart`, `client/test/widget/message_bubble_test.dart` |
| SURF-GROUP-SHELL-002, SURF-GROUP-SHELL-003, SURF-GROUP-SHELL-007 | `group_conversation_screen_test.dart`, `home_screen_group_test.dart`, `account_sidebar_test.dart`, `inbox_controller_group_test.dart` |
| SURF-AUTH-006 | `AuthScreen` — verifica manuale / e2e |
| PROM-MULTI-ACCOUNT-031 | `account_manager_persistence_test.dart` (`profileKind` manifest) |

**Gate**: `bash scripts/check-spec-sync.sh` + `cd client && bash scripts/verify.sh` + smoke SQL gruppo + `integration` esteso

---

## 8. Scenari di accettazione (backend)

```gherkin
Scenario: Recapito al gruppo e erogazione automatica
  Given gruppo G con P e Q in allow list
  And P e Q hanno G nei propri consentiti
  When U invia a G con gate U↔G soddisfatto
  Then copia U ha delivered_at valorizzato
  And storico G contiene messaggio con author U
  And archivio P contiene erogazione author G, original_author U, peer G

Scenario: Erogazione bloccata — allow list persona
  Given G eroga verso P ma P ha rimosso G dai consentiti
  When U invia a G
  Then storico G riceve messaggio
  And nessuna nuova riga erogata in archivio P

Scenario: Gruppo broadcast
  Given sessione auth.uid() = G con P in allow list
  When G invia broadcast
  Then storico G contiene una riga con original_author G
  And archivio P contiene copia author G, original_author G, peer G
```

---

## 9. Fuori scope

- Ruoli granulari (admin, moderatore)
- Federazione MUC / stanze XMPP
- Spunte «letto da tutti i membri» aggregate per mittente originale
- Media GC specifico gruppo

---

## 10. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [SYS-MAILBOX](./SYS-MAILBOX.md) | Archivio, invio, lettura |
| [contracts/schema.md](../../contracts/schema.md) | Dettaglio schema gruppi |
| [contracts/rpc.md](../../contracts/rpc.md) | RPC gruppo / broadcast |
| [SYS-RECEPTION](./SYS-RECEPTION.md) | Gate recapito |
