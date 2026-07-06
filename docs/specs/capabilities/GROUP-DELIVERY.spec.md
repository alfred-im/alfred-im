# GROUP-DELIVERY — Invio, erogazione e spunte gruppo

| Campo | Valore |
|-------|--------|
| **Spec ID** | `GROUP-DELIVERY` |
| **Layer** | capability |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-06 |
| **ADR** | [mailbox-inbox-outbox-spec.md](../../architecture/mailbox-inbox-outbox-spec.md), [server-as-reception.md](../../decisions/server-as-reception.md) |
| **PR** | — |
| **Correlata** | [GROUP-CORE](./GROUP-CORE.spec.md), [MAILBOX-SEND](./MAILBOX-SEND.spec.md), [MAILBOX-READ](./MAILBOX-READ.spec.md), [RECEPTION-ALLOWLIST](./RECEPTION-ALLOWLIST.spec.md) |

Documento per AI — recapito verso/da account gruppo, erogazione automatica verso allow list del gruppo, semantica `author_id` / `original_author_id`, spunte limitate al rapporto mittente↔gruppo.

---

## 1. Problema / obiettivo

Un account **user** invia a `@gruppo` come a qualsiasi profilo. Il messaggio viene **recapitato** allo storico del gruppo. Il gruppo **eroga** automaticamente verso ogni persona nella **propria** allow list, con gli stessi gate allow list delle chat private. L'erogazione **non** aggiorna le spunte del messaggio originale oltre il recapito al gruppo.

Messaggi erogati: mittente tecnico = **gruppo**; autore contenuto = **umano** (`original_author_id`) o assente se il gruppo scrive a nome proprio.

---

## 2. Requisiti

### MUST

| ID | Requisito |
|----|-----------|
| **GROUP-DELIVERY-REQ-001** | Invio verso gruppo: stesso RPC `send_message_to_profile(p_recipient_profile_id)` quando destinatario ha `profile_kind = group` |
| **GROUP-DELIVERY-REQ-002** | Pipeline invariata fino al gate allow list: copia mittente umano, outbox, λ |
| **GROUP-DELIVERY-REQ-003** | Gate recapito umano→gruppo: identico a chat private — mittente umano ∈ `reception_allowlist` del **gruppo**; gruppo ∈ allow list del **mittente** (entrambi richiesti per recapito) |
| **GROUP-DELIVERY-REQ-004** | Su recapito al gruppo: INSERT riga archivio gruppo (`owner_id = gruppo`); `author_id = mittente umano`; `peer_profile_id = mittente umano`; `original_author_id = NULL` |
| **GROUP-DELIVERY-REQ-005** | Su recapito al gruppo: UPDATE copia mittente umano `delivered_at = now()` (✓✓ = **gruppo ha ricevuto**) |
| **GROUP-DELIVERY-REQ-006** | **Erogazione automatica**: nella **stessa transazione** dopo INSERT storico gruppo, per ogni `allowed_profile_id` nella `reception_allowlist` del gruppo (`owner_id = gruppo`) tentare recapito verso quella persona |
| **GROUP-DELIVERY-REQ-007** | Gate erogazione gruppo→persona: stesso meccanismo allow list — **gruppo** come mittente tecnico ∈ allow list della **persona**; persona ∈ allow list del **gruppo** (già in lista per definizione del loop; gate persona↔gruppo deve essere bidirezionale) |
| **GROUP-DELIVERY-REQ-008** | Riga erogata su archivio persona: `owner_id = persona`; `author_id = gruppo` (mittente tecnico); `original_author_id = mittente umano originale`; `peer_profile_id = gruppo`; stesso λ della catena |
| **GROUP-DELIVERY-REQ-009** | UI messaggio erogato: testo attribuito graficamente a **chi ha scritto** (`original_author_id`); contesto conversazione con **gruppo** (`peer_profile_id`) |
| **GROUP-DELIVERY-REQ-010** | Gruppo scrive a nome proprio (property/admin): `send_message_to_profile` con `auth.uid() = gruppo`; `author_id = gruppo`; `original_author_id = NULL`; recapito verso destinatario con gate allow list standard |
| **GROUP-DELIVERY-REQ-011** | Erogazione verso persona che **non** passa il gate: skip silenzioso (nessun errore verso gruppo o mittente originale); **non** aggiorna spunte del messaggio originale |
| **GROUP-DELIVERY-REQ-012** | Spunte messaggio **originale** (umano→gruppo): solo ✓ accettato e ✓✓ **recapitato al gruppo**; erogazione verso altri partecipanti **non** modifica `delivered_at` / `read_at` della copia del mittente originale |
| **GROUP-DELIVERY-REQ-013** | Spunte messaggio **erogato** (su archivio persona): semantica [MAILBOX-READ](./MAILBOX-READ.spec.md) tra persona e peer **gruppo** — indipendenti dal mittente umano originale |
| **GROUP-DELIVERY-REQ-014** | Rimozione allow list: messaggi già in archivio **restano**; solo recapiti **nuovi** bloccati — [RECEPTION-ALLOWLIST-REQ-011](./RECEPTION-ALLOWLIST.spec.md) |
| **GROUP-DELIVERY-REQ-015** | Colonna `messages.original_author_id` uuid nullable FK → `profiles` — autore contenuto quando `author_id` è gruppo |
| **GROUP-DELIVERY-REQ-016** | Idempotenza erogazione: UNIQUE `(owner_id, logical_message_id)` per ogni destinatario erogato (già [MAILBOX-CORE-REQ-005](./MAILBOX-CORE.spec.md)) |
| **GROUP-DELIVERY-REQ-017** | Account `user`: `list_inbox()` e `list_peer_messages(gruppo)` includono messaggi erogati con `peer_profile_id = gruppo` |
| **GROUP-DELIVERY-REQ-018** | Account `group`: storico via query su `messages` WHERE `owner_id = auth.uid()` ORDER BY `created_at` (non `list_inbox`) |

### SHOULD

| ID | Requisito |
|----|-----------|
| **GROUP-DELIVERY-REQ-019** | Realtime: subscribe `messages` `owner_id = io` — account user riceve INSERT erogati; account group riceve INSERT in entrata |
| **GROUP-DELIVERY-REQ-020** | Preview inbox per messaggio erogato: prefisso o formato che indica autore umano se `original_author_id` valorizzato |

### MUST NOT

| ID | Requisito |
|----|-----------|
| **GROUP-DELIVERY-REQ-021** | Aggiornare `delivered_at` del mittente umano originale quando erogazione verso **terzi** riesce o fallisce |
| **GROUP-DELIVERY-REQ-022** | Erogazione manuale / «inoltra» in v1 — sempre automatica su recapito al gruppo |
| **GROUP-DELIVERY-REQ-023** | Tabella membership per decidere target erogazione — **solo** `reception_allowlist` del gruppo |
| **GROUP-DELIVERY-REQ-024** | `author_id = umano` su righe erogate verso partecipanti (mittente tecnico deve essere gruppo) |
| **GROUP-DELIVERY-REQ-025** | Esporre al mittente umano quali partecipanti hanno ricevuto l'erogazione |
| **GROUP-DELIVERY-REQ-026** | Retro-recapito erogazione dopo aggiunta tardiva ad allow list |

---

## 3. Fuori scope

- Spunte «letto da tutti i membri» aggregate per mittente originale
- Broadcast compose gruppo→tutti in un solo RPC (v1: invio per destinatario o loop interno)
- Media GC specifico gruppo
- Federazione gruppo

---

## 4. Contratto

### 4.1 Semantica autori

| Situazione | `author_id` | `original_author_id` | `peer_profile_id` (archivio persona) |
|------------|-------------|----------------------|--------------------------------------|
| Umano invia a gruppo (copia umano) | umano | NULL | gruppo |
| Stesso messaggio su storico gruppo | umano | NULL | umano |
| Erogazione verso persona | **gruppo** | umano | **gruppo** |
| Gruppo scrive a persona | **gruppo** | NULL | persona |

### 4.2 Flusso umano → gruppo → erogazione (transazione RPC)

```
send_message_to_profile(destinatario = G, G.profile_kind = group)
  → INSERT copia mittente U (author=U, peer=G, λ)
  → outbox
  → SE gate allow U↔G:
       INSERT storico gruppo (owner=G, author=U, peer=U, λ)
       UPDATE copia U delivered_at = now()     ← ✓✓ verso gruppo
       PER OGNI P in reception_allowlist(owner=G):
         SE gate allow G↔P:
           INSERT erogazione (owner=P, author=G, original_author=U, peer=G, λ)
         ALTRIMENTI skip silenzioso
     ALTRIMENTI:
       delivered_at null su copia U (✓ solo)
  → RETURN copia U
```

### 4.3 Flusso gruppo → persona (compose admin)

```
send_message_to_profile(destinatario = P) con auth.uid() = G
  → INSERT copia gruppo (owner=G, author=G, peer=P, original_author=NULL)
  → gate allow G↔P
  → SE ok: INSERT copia P (owner=P, author=G, peer=G, original_author=NULL)
  → RETURN copia gruppo
```

### 4.4 Spunte (v1)

| Copia | `delivered_at` significa |
|-------|-------------------------|
| Umano → gruppo | Recapitato al **gruppo** |
| Erogazione su persona | Non tocca copia umano originale |
| Persona legge chat con gruppo | `mark_peer_read(gruppo)` — [MAILBOX-READ](./MAILBOX-READ.spec.md) |

### 4.5 Client

| Componente | Responsabilità |
|------------|----------------|
| `ChatMessage` | Mostra nome da `original_author_id` se presente, altrimenti `author_id` |
| `MessageService` | RPC invariato; nessun parametro extra lato client per erogazione |
| `GroupConversationScreen` | Lista messaggi archivio gruppo; compose come gruppo |
| `MessagesController` | Peer gruppo su account user — rendering autore da `original_author_id` |

---

## 5. Tracciabilità (requisito → verifica)

| REQ-ID | Verifica |
|--------|----------|
| GROUP-DELIVERY-REQ-001–008, 011–012 | `supabase/tests/group_delivery_smoke.sql` |
| GROUP-DELIVERY-REQ-010 | `broadcast_message_to_allowlist` in migrazione + shell gruppo |
| GROUP-DELIVERY-REQ-014 | gate in `send_message_to_profile` (stesso smoke) |
| GROUP-DELIVERY-REQ-015 | `supabase/tests/group_schema_smoke.sql` |
| GROUP-DELIVERY-REQ-009 | `client/test/unit/group_message_display_test.dart` |

Gate implementazione: `check-spec-sync.sh` + `verify.sh` + smoke SQL + `integration` esteso.

---

## 6. Scenari di accettazione

```gherkin
Scenario: Recapito al gruppo e erogazione automatica
  Given gruppo G con P e Q in allow list
  And P e Q hanno G nei propri consentiti
  When U invia a G con gate U↔G soddisfatto
  Then copia U ha delivered_at valorizzato
  And storico G contiene messaggio con author U
  And archivio P contiene erogazione author G, original_author U, peer G
  And archivio Q idem

Scenario: Erogazione bloccata — allow list persona
  Given G eroga verso P ma P ha rimosso G dai consentiti
  When U invia a G
  Then storico G riceve messaggio
  And nessuna nuova riga erogata in archivio P
  And delivered_at copia U invariato rispetto a recapito solo gruppo

Scenario: Gruppo scrive a nome proprio
  Given sessione auth.uid() = G
  When G invia a P con gate soddisfatto
  Then copia P ha author G, original_author null, peer G

Scenario: Mittente non in allow list gruppo
  Given U non in allow list di G
  When U invia a G
  Then copia U delivered_at null
  And nessuna riga in storico G
```

---

## 7. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [GROUP-CORE](./GROUP-CORE.spec.md) | Account e partecipazione |
| [MAILBOX-SEND](./MAILBOX-SEND.spec.md) | Pipeline outbox |
| [RECEPTION-ALLOWLIST](./RECEPTION-ALLOWLIST.spec.md) | Gate |

**Codice target**: `supabase/migrations/*group*`, `send_message_to_profile` body, `client/lib/models/chat_message.dart`
