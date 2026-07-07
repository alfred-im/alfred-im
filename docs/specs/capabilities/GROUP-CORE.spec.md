# GROUP-CORE — Account gruppo e partecipazione

| Campo | Valore |
|-------|--------|
| **Spec ID** | `GROUP-CORE` |
| **Layer** | capability |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-06 |
| **ADR** | [address-based-messaging.md](../../decisions/address-based-messaging.md), [mailbox-inbox-outbox-spec.md](../../architecture/mailbox-inbox-outbox-spec.md) |
| **PR** | #162 |
| **Correlata** | [PROFILE](./PROFILE.spec.md), [AUTH-MULTI](./AUTH-MULTI.spec.md), [RECEPTION-ALLOWLIST](./RECEPTION-ALLOWLIST.spec.md), [GROUP-DELIVERY](./GROUP-DELIVERY.spec.md) |

Documento per AI — account Alfred di tipo **gruppo**: identità, registrazione, shell client, partecipazione tramite allow list bidirezionale (nessuna membership separata).

**Discovery**: 2026-07-06 — gruppo = account con `profile_kind = group`; partecipazione ≡ allow list; niente inviti/iscrizione al gruppo.

---

## 1. Problema / obiettivo

Un **gruppo** è un'identità Alfred (`@famiglia`) con account proprio (GoTrue + profilo), indipendente da chi lo crea. I **partecipanti** (account `user`) interagiscono con il gruppo come con qualsiasi peer in messaggistica. La **partecipazione** e la **gestione accessi** usano **solo** `reception_allowlist` — stesso meccanismo delle chat private, senza tabelle membership o flussi invito/accettazione.

L'account gruppo ha shell dedicata: profilo standard, allow list standard (in alto), **una** vista conversazione (storico) — **non** inbox a lista di conversazioni.

---

## 2. Requisiti

### MUST

| ID | Requisito |
|----|-----------|
| **GROUP-CORE-REQ-001** | Enum `profile_kind`: `user` \| `group` su `profiles`; default `user` per righe esistenti |
| **GROUP-CORE-REQ-002** | Username gruppo: stesso namespace e regex di [PROFILE-REQ-002](./PROFILE.spec.md) — univoco case-insensitive tra **tutti** i profili |
| **GROUP-CORE-REQ-003** | Creazione gruppo = registrazione GoTrue (email reale, password, username) con `profile_kind = group` in `raw_user_meta_data` (o equivalente backend) |
| **GROUP-CORE-REQ-004** | Client registrazione: stessa schermata auth utente con opzione tipo account (`user` / `group`); nessuna schermata signup dedicata obbligatoria |
| **GROUP-CORE-REQ-005** | Dopo login account gruppo: compare nel manifest multi-account come ogni altro account — [AUTH-MULTI](./AUTH-MULTI.spec.md) |
| **GROUP-CORE-REQ-006** | Account gruppo in focus: shell **senza** `list_inbox()` — solo vista conversazione (storico unico) + entry profilo + entry allow list |
| **GROUP-CORE-REQ-007** | Layout shell gruppo: allow list e profilo come account `user`; allow list **sopra** la conversazione (analogo a allow list sopra inbox su account umano) |
| **GROUP-CORE-REQ-008** | Partecipazione a un gruppo: **solo** consenso bidirezionale allow list — gruppo aggiunge persona alla **propria** `reception_allowlist`; persona aggiunge gruppo alla **propria** `reception_allowlist` |
| **GROUP-CORE-REQ-009** | **Nessuna** tabella `group_members`, `group_invitations`, RPC invito/accettazione, UI invita/rimuovi separata dalla allow list |
| **GROUP-CORE-REQ-010** | **Nessuna** «iscrizione al gruppo» — aprire chat con `@gruppo` = compose verso indirizzo come [address-based-messaging](../../decisions/address-based-messaging.md) |
| **GROUP-CORE-REQ-011** | Chi crea un gruppo può esistere **solo** come account gruppo; account personale opzionale per partecipare ad altri gruppi come qualsiasi `user` |
| **GROUP-CORE-REQ-012** | Ogni gruppo = un account distinto; un secondo gruppo = seconda registrazione (`@altro_gruppo`) — eventuale multi-account con più profili `group` nel manifest |
| **GROUP-CORE-REQ-013** | Profilo gruppo: stessi campi e UI di [PROFILE](./PROFILE.spec.md) (`display_name`, `bio`, `avatar_url`, `pronouns`; username non editabile) |
| **GROUP-CORE-REQ-014** | `find_profile_by_username` ritorna anche `profile_kind` (o campo equivalente) per routing client shell |
| **GROUP-CORE-REQ-015** | Account `user`: inbox e chat invariati; peer gruppo = `peer_profile_id` del profilo gruppo |

### SHOULD

| ID | Requisito |
|----|-----------|
| **GROUP-CORE-REQ-016** | Etichetta UI distinta per account `group` nel manifest (es. badge «Gruppo») |
| **GROUP-CORE-REQ-017** | Vista storico gruppo: messaggi ordinati per `created_at` su tutto l'archivio `owner_id = gruppo` |

### MUST NOT

| ID | Requisito |
|----|-----------|
| **GROUP-CORE-REQ-018** | Email sintetiche GoTrue (`alfred.*@gmail.com`, `@users.alfred.*`) per account gruppo |
| **GROUP-CORE-REQ-019** | Obbligo di account personale per chi crea un gruppo |
| **GROUP-CORE-REQ-020** | Inbox a lista conversazioni quando focus su account `group` |
| **GROUP-CORE-REQ-021** | Tabella membership o cache partecipanti oltre `reception_allowlist` |
| **GROUP-CORE-REQ-022** | Flusso «richiedi di entrare nel gruppo» o conferma invito |
| **GROUP-CORE-REQ-023** | Rubrica (`contacts`) come prerequisito per partecipare o scrivere al gruppo |

---

## 3. Fuori scope

- Ruoli granulari (admin, moderatore) — futuro; v1 property = account gruppo + allow list
- Federazione MUC / stanze XMPP
- Allow list simmetrica su invio 1:1 (correzione piattaforma separata)
- Messaggistica gruppo → vedi [GROUP-DELIVERY](./GROUP-DELIVERY.spec.md)

---

## 4. Contratto

### 4.1 Backend — `profiles`

| Elemento | Comportamento |
|----------|---------------|
| `profile_kind` | `user` (default) \| `group` |
| Trigger `handle_new_user` | Legge `profile_kind` da metadata; crea profilo coerente |
| RLS | Invariata — `id = auth.uid()` per UPDATE proprio profilo |

Vedi [contracts/schema.md](../contracts/schema.md) § target gruppi.

### 4.2 Backend — partecipazione

```
Partecipazione effettiva ⇔
  EXISTS reception_allowlist(owner_id = gruppo, allowed_profile_id = persona)
  AND EXISTS reception_allowlist(owner_id = persona, allowed_profile_id = gruppo)
```

Rimozione da una delle due liste → recapito bloccato verso la direzione corrispondente (semantica [RECEPTION-ALLOWLIST](./RECEPTION-ALLOWLIST.spec.md)); storico già recapitato **resta**.

### 4.3 Client — registrazione

| Componente | Responsabilità |
|------------|----------------|
| `AuthScreen` | Toggle o opzione `Account personale` / `Account gruppo` |
| `AuthController.signUp` | Passa `profile_kind` in `user_metadata` |
| `AccountManager` | Nessun trattamento speciale manifest salvo shell al focus |

### 4.4 Client — shell gruppo

| Componente | Responsabilità |
|------------|----------------|
| `HomeScreen` (o equivalente) | Se `profile_kind == group`: nasconde inbox panel; mostra `GroupConversationScreen` |
| `GroupConversationScreen` | Storico unico + compose; header con link profilo e allow list |
| `AllowedPeopleScreen` | Riuso invariato — titolo «Persone consentite» |
| `ProfileScreen` | Riuso invariato |

### 4.5 UX

| Condizione | Comportamento atteso |
|------------|----------------------|
| Registrazione gruppo | Email + password + username; stessa UX auth |
| Login come `@famiglia` | Manifest + shell conversazione unica |
| Login come `@mario` | Inbox normale; `@famiglia` come peer se in allow list |
| Aggiungere partecipante | Gruppo aggiunge persona in allow list; persona aggiunge gruppo nella propria |
| Nessun invito | Nessuna notifica «invito gruppo» obbligatoria in v1 |

---

## 5. Tracciabilità (requisito → verifica)

| REQ-ID | Verifica |
|--------|----------|
| GROUP-CORE-REQ-001–003 | `supabase/tests/group_schema_smoke.sql` |
| GROUP-CORE-REQ-004 | `AuthScreen` (toggle tipo account) — verifica manuale / e2e |
| GROUP-CORE-REQ-006–007, 016 | `client/test/widget/group_conversation_screen_test.dart`, `client/test/unit/inbox_controller_group_test.dart` |
| GROUP-CORE-REQ-008–009 | `supabase/tests/group_delivery_smoke.sql` (gate bidirezionale) |
| GROUP-CORE-REQ-014 | `group_schema_smoke.sql` + `find_profile_by_username` client |
| GROUP-CORE-REQ-005 | `account_manager_persistence_test.dart` (`profileKind` manifest) |

Gate implementazione: `check-spec-sync.sh` + `verify.sh` + smoke SQL gruppo.

---

## 6. Scenari di accettazione

```gherkin
Scenario: Creazione account gruppo
  Given utente non autenticato
  When registra account tipo gruppo con email, password, username "famiglia"
  Then esiste profiles con profile_kind = group e username "famiglia"
  And dopo login compare nel manifest

Scenario: Partecipazione solo allow list
  Given gruppo G e persona P
  When G aggiunge P alla propria allow list
  And P NON aggiunge G alla propria allow list
  Then P non riceve erogazione da G (vedi GROUP-DELIVERY)
  And invio P verso G resta a ✓ singola se gate non soddisfatto

Scenario: Partecipazione bidirezionale
  Given G e P si sono aggiunti reciprocamente in allow list
  Then P può inviare a G e ricevere erogazione da G secondo GROUP-DELIVERY

Scenario: Shell gruppo senza inbox
  Given focus su account gruppo G
  When carico home
  Then non chiamo list_inbox per navigazione principale
  And vedo storico conversazione unico
```

---

## 7. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [GROUP-DELIVERY](./GROUP-DELIVERY.spec.md) | Invio, erogazione, autori, spunte |
| [RECEPTION-ALLOWLIST](./RECEPTION-ALLOWLIST.spec.md) | Gate recapito |
| [PROFILE](./PROFILE.spec.md) | Campi profilo |
| [AUTH-MULTI](./AUTH-MULTI.spec.md) | Manifest e focus |

**Codice target**: `supabase/migrations/*group*`, `client/lib/screens/auth_screen.dart`, `client/lib/screens/group_conversation_screen.dart`, `client/lib/screens/home_screen.dart`
