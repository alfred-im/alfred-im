# RECEPTION-ALLOWLIST — Filtro ricezione personale

| Campo | Valore |
|-------|--------|
| **Spec ID** | `RECEPTION-ALLOWLIST` |
| **Layer** | capability |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-04 |
| **ADR** | [server-as-reception.md](../../decisions/server-as-reception.md), [mailbox-inbox-outbox-spec.md](../../architecture/mailbox-inbox-outbox-spec.md), [bridge-stateless.md](../../decisions/bridge-stateless.md) |
| **PR** | #161 |
| **Correlata** | [MAILBOX-SEND](./MAILBOX-SEND.spec.md), [MAILBOX-READ](./MAILBOX-READ.spec.md), [CONTACTS](./CONTACTS.spec.md), [AUTH-MULTI](./AUTH-MULTI.spec.md) |

Documento per AI — allow list personale di ricezione: chi non è in lista non ha messaggi materializzati nel mio archivio; rifiuto silenzioso stile blocco XMPP.

---

## 1. Problema / obiettivo

L’utente Alfred controlla **chi può consegnargli messaggi** tramite una lista personale di profili consentiti. Il filtro è **sempre attivo** (nessun toggle on/off). Lista vuota = nessuno può recapitare.

**Semantica spunte (mittente)** — due livelli distinti ([server-as-reception.md](../../decisions/server-as-reception.md)):

1. **✓** — il server ha **accettato** il messaggio (copia mittente persistita; RPC ok).
2. **✓✓ grigie** — il messaggio è **consegnato** al destinatario (copia nel suo archivio; `delivered_at` valorizzato).

Su rifiuto allow list: il mittente resta al livello **1** per sempre (mai livello 2) — come blocco XMPP, senza errore né etichetta «bloccato». I messaggi rifiutati non vengono mai scritti nell’archivio destinatario.

La rubrica (`contacts`) resta **isolata**: essere in rubrica non implica essere consentiti in ricezione.

---

## 2. Requisiti

### MUST

| ID | Requisito |
|----|-----------|
| **RECEPTION-ALLOWLIST-REQ-001** | Tabella `reception_allowlist` scoped per `owner_id` (destinatario che filtra) con RLS `owner_id = auth.uid()` |
| **RECEPTION-ALLOWLIST-REQ-002** | Colonne: `id` uuid PK, `owner_id` FK → profiles, `allowed_profile_id` FK → profiles, `created_at` timestamptz |
| **RECEPTION-ALLOWLIST-REQ-003** | Unicità `(owner_id, allowed_profile_id)`; `allowed_profile_id ≠ owner_id` |
| **RECEPTION-ALLOWLIST-REQ-004** | CRUD lista via PostgREST diretto su `reception_allowlist` (nessuna RPC dedicata obbligatoria) |
| **RECEPTION-ALLOWLIST-REQ-005** | Gate server **prima** della materializzazione copia destinatario in `send_message_to_profile` (driver internal) |
| **RECEPTION-ALLOWLIST-REQ-006** | Condizione recapito: esiste riga `reception_allowlist` con `owner_id = destinatario` AND `allowed_profile_id = mittente` |
| **RECEPTION-ALLOWLIST-REQ-007** | Lista vuota → **nessun** mittente soddisfa il gate → tutti i messaggi nuovi rifiutati |
| **RECEPTION-ALLOWLIST-REQ-008** | Su rifiuto: INSERT copia mittente + outbox come oggi; **nessuna** INSERT copia destinatario; `delivered_at` resta null sulla copia mittente |
| **RECEPTION-ALLOWLIST-REQ-009** | Su rifiuto: RPC ritorna la copia mittente senza errore (rifiuto silenzioso) |
| **RECEPTION-ALLOWLIST-REQ-010** | Su rifiuto: outbox internal → `status = completed` (job processato); payload può includere `reception_rejected: true` solo per audit server — **mai** esposto al client mittente |
| **RECEPTION-ALLOWLIST-REQ-011** | Rimozione da lista: messaggi già presenti nell’archivio destinatario **restano**; solo i messaggi **nuovi** dopo la rimozione sono rifiutati |
| **RECEPTION-ALLOWLIST-REQ-012** | Aggiunta a lista: **nessuna** retro-consegna di messaggi precedentemente rifiutati |
| **RECEPTION-ALLOWLIST-REQ-013** | Nuovo account: lista vuota di default (nessuno può scrivere finché non si aggiunge qualcuno) |
| **RECEPTION-ALLOWLIST-REQ-014** | Filtro sempre attivo — **nessun** flag globale enable/disable a livello utente o piattaforma |
| **RECEPTION-ALLOWLIST-REQ-015** | UI: schermata «Persone consentite» raggiungibile dall’icona accanto a «Contatti» in header inbox (`InboxPanel`) |
| **RECEPTION-ALLOWLIST-REQ-016** | UI: aggiunta manuale persona (ricerca `search_profiles`, stesso minimo 2 caratteri di rubrica) e rimozione dalla lista |
| **RECEPTION-ALLOWLIST-REQ-017** | `ReceptionAllowlistController` legato all’account in **focus** — [AUTH-MULTI](./AUTH-MULTI.spec.md) |
| **RECEPTION-ALLOWLIST-REQ-018** | Stesso gate documentato per recapito **federato** (bridge XMPP/Matrix fase B): prima di materializzare copia ingresso su Alfred, verificare allow list del destinatario; stesso silenzio verso mittente esterno (nessun ack consegna / XEP-0184) |

### SHOULD

| ID | Requisito |
|----|-----------|
| **RECEPTION-ALLOWLIST-REQ-019** | Lista ordinata per `display_name` del profilo consentito (join `profiles`) |
| **RECEPTION-ALLOWLIST-REQ-020** | Dopo add/remove: reload lista client |

### MUST NOT

| ID | Requisito |
|----|-----------|
| **RECEPTION-ALLOWLIST-REQ-021** | Errore RPC, codice errore o messaggio «bloccato» / «rifiutato» verso il mittente |
| **RECEPTION-ALLOWLIST-REQ-022** | Usare tabella `contacts` come fonte o proxy dell’allow list |
| **RECEPTION-ALLOWLIST-REQ-023** | Materializzare copia destinatario su rifiuto (anche temporanea o «nascosta») |
| **RECEPTION-ALLOWLIST-REQ-024** | Retro-consegnare messaggi rifiutati quando si aggiunge un profilo alla lista |
| **RECEPTION-ALLOWLIST-REQ-025** | Eliminare dall’archivio messaggi già ricevuti quando si rimuove qualcuno dalla lista |
| **RECEPTION-ALLOWLIST-REQ-026** | Toggle globale on/off della funzionalità allow list |
| **RECEPTION-ALLOWLIST-REQ-027** | Mostrare al mittente che il destinatario usa un filtro di ricezione |

---

## 3. Fuori scope (questa capability)

- Toggle «consenti ricezione» nella scheda profilo persona — **implementato** in [PEER-PROFILE](./PEER-PROFILE.spec.md) (PR #163); schermata lista «Persone consentite» resta entry dedicata
- Allow list per indirizzi federati non risolti a `profiles.id` (fase B: mapping identità bridge → `allowed_profile_id` o estensione schema)
- Notifiche push al destinatario per messaggi rifiutati
- Coda «messaggi in attesa di consenso»

---

## 4. Contratto

### 4.1 Backend — `reception_allowlist`

| Elemento | Comportamento |
|----------|---------------|
| `owner_id` | Utente che filtra la propria ricezione |
| `allowed_profile_id` | Profilo Alfred il cui mittente può consegnare |
| RLS | SELECT/INSERT/DELETE solo `owner_id = auth.uid()` |
| CHECK | `allowed_profile_id IS NOT NULL` AND `allowed_profile_id <> owner_id` |

Vedi [contracts/schema.md](../contracts/schema.md).

### 4.2 Backend — gate recapito (internal)

```
send_message_to_profile
  → INSERT copia mittente (livello ✓ — accettato server)
  → SE EXISTS reception_allowlist(owner=dest, allowed=mittente):
       INSERT copia destinatario
       UPDATE mittente delivered_at = now()  (livello ✓✓)
       outbox status = completed
     ALTRIMENTI:
       skip copia destinatario
       delivered_at resta null  (resta livello ✓)
       outbox status = completed (payload opz. reception_rejected)
  → RETURN copia mittente
```

Funzione helper consigliata (implementazione): `is_sender_allowed_for_reception(p_owner_id, p_sender_profile_id) boolean` — `SECURITY DEFINER`, usata da RPC invio e futuro bridge.

Modifica [MAILBOX-SEND-REQ-004](./MAILBOX-SEND.spec.md): consegna internal **condizionata** al gate.

### 4.3 Backend — federazione (fase B)

Stesso gate nel consumer bridge **prima** di INSERT copia ingresso su archivio Alfred. Se rifiutato: nessuna copia destinatario; nessun ack consegna verso dominio esterno; outbox/job completato lato piattaforma.

### 4.4 Client

| Componente | Responsabilità |
|------------|----------------|
| `ReceptionAllowlistService` | CRUD PostgREST su `reception_allowlist`; fetch con join profili |
| `ReceptionAllowlistController` | Stato lista, search add, remove; `ownerId` = focus |
| `AllowedPeopleScreen` | Titolo UI: **«Persone consentite»** |
| `InboxPanel` | Icona entry accanto a «Contatti» |
| `HomeScreen` | Navigazione verso schermata allow list |

### 4.5 UX

| Condizione | Comportamento atteso |
|------------|----------------------|
| Header inbox | Icona «Persone consentite» accanto a icona rubrica |
| Lista vuota (UI) | Messaggio esplicativo: nessuno può consegnarti messaggi finché non aggiungi qualcuno |
| Mittente non allowed | Livello **✓** permanente (server ha accettato; mai ✓✓) — nessun feedback blocco |
| Destinatario | Non vede messaggi rifiutati; inbox invariata per messaggi già archiviati |

---

## 5. Tracciabilità (requisito → verifica)

| REQ-ID | Verifica |
|--------|----------|
| RECEPTION-ALLOWLIST-REQ-001–004 | `supabase/tests/reception_allowlist_schema_smoke.sql` |
| RECEPTION-ALLOWLIST-REQ-005–010 | `supabase/tests/reception_allowlist_gate_smoke.sql` |
| RECEPTION-ALLOWLIST-REQ-007 | `reception_allowlist_gate_smoke.sql` — lista vuota |
| RECEPTION-ALLOWLIST-REQ-011–012 | `reception_allowlist_gate_smoke.sql` |
| RECEPTION-ALLOWLIST-REQ-015–017 | `client/test/unit/reception_allowlist_controller_test.dart` |
| RECEPTION-ALLOWLIST-REQ-005–009 | `bash scripts/test.sh integration` |
| MAILBOX-SEND-REQ-004 (aggiornato) | `mailbox_delivery_smoke.sql` + gate smoke |

Gate implementazione: `check-spec-sync.sh` + `verify.sh` + smoke SQL + `integration`.

---

## 6. Scenari di accettazione

```gherkin
Scenario: Rifiuto silenzioso — accettato server ma non consegnato
  Given destinatario D con reception_allowlist vuota
  When mittente M invia messaggio a D
  Then RPC successo per M
  And copia mittente esiste in archivio M (livello ✓)
  And copia M ha delivered_at null (mai livello ✓✓)
  And nessuna riga in archivio D per quel λ

Scenario: Lista vuota rifiuta tutti
  Given destinatario D con reception_allowlist vuota
  When mittente M invia messaggio a D
  Then RPC successo per M
  And copia M ha delivered_at null
  And nessuna riga in archivio D per quel λ

Scenario: Profilo in lista consente recapito
  Given D ha M in reception_allowlist
  When M invia a D
  Then copia destinatario esiste
  And delivered_at valorizzato su copia M

Scenario: Rimozione non cancella storico
  Given D ha messaggi da M in archivio
  When D rimuove M dalla allow list
  And M invia nuovo messaggio
  Then messaggi precedenti restano in archivio D
  And nuovo messaggio non è in archivio D
```

---

## 7. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [MAILBOX-SEND](./MAILBOX-SEND.spec.md) | RPC invio; REQ-004 condizionato |
| [MAILBOX-READ](./MAILBOX-READ.spec.md) | Spunte — `delivered_at` null = ✓ singola |
| [CONTACTS](./CONTACTS.spec.md) | Rubrica isolata |
| [server-as-reception.md](../../decisions/server-as-reception.md) | Semantica consegna server |

**Codice target**: `supabase/migrations/`, `client/lib/screens/allowed_people_screen.dart`, `client/lib/providers/reception_allowlist_controller.dart`, `client/lib/services/reception_allowlist_service.dart`, `client/lib/widgets/inbox_panel.dart`
