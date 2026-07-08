# SYS-RECEPTION — Filtro ricezione personale (piattaforma)

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `SYS-RECEPTION` |
| **Classe** | SYSTEM |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-08 |
| **Contratti** | [schema.md](../../contracts/schema.md) · [rpc.md](../../contracts/rpc.md) |
| **PR** | #161 |

Promesse di piattaforma per `reception_allowlist`, gate recapito in `send_message_to_profile` e semantica rifiuto silenzioso — filtro sempre attivo, isolato da rubrica.

---

## 1. Problema / obiettivo

L'utente Alfred controlla chi può consegnargli messaggi tramite allow list personale. Il backend materializza la copia destinatario solo se il mittente è in lista; su rifiuto il mittente resta a livello ✓ (accettato server) senza ✓✓ (consegnato).

---

## 2. Promesse SYSTEM

### MUST

| ID | Promessa |
|----|----------|
| **SYS-RECEPTION-001** | Tabella `reception_allowlist` scoped per `owner_id` (destinatario che filtra) con RLS `owner_id = auth.uid()` |
| **SYS-RECEPTION-002** | Colonne: `id` uuid PK, `owner_id` FK → profiles, `allowed_profile_id` FK → profiles, `created_at` timestamptz |
| **SYS-RECEPTION-003** | Unicità `(owner_id, allowed_profile_id)`; `allowed_profile_id ≠ owner_id` |
| **SYS-RECEPTION-004** | CRUD lista via PostgREST diretto su `reception_allowlist` (nessuna RPC dedicata obbligatoria) |
| **SYS-RECEPTION-005** | Gate server **prima** della materializzazione copia destinatario in `send_message_to_profile` (driver internal) |
| **SYS-RECEPTION-006** | Condizione recapito: esiste riga `reception_allowlist` con `owner_id = destinatario` AND `allowed_profile_id = mittente` |
| **SYS-RECEPTION-007** | Lista vuota → **nessun** mittente soddisfa il gate → tutti i messaggi nuovi rifiutati |
| **SYS-RECEPTION-008** | Su rifiuto: INSERT copia mittente + outbox come oggi; **nessuna** INSERT copia destinatario; `delivered_at` resta null sulla copia mittente |
| **SYS-RECEPTION-009** | Su rifiuto: RPC ritorna la copia mittente senza errore (rifiuto silenzioso) |
| **SYS-RECEPTION-010** | Su rifiuto: outbox internal → `status = completed`; payload può includere `reception_rejected: true` solo per audit server — **mai** esposto al client mittente |
| **SYS-RECEPTION-011** | Rimozione da lista: messaggi già presenti nell'archivio destinatario **restano**; solo i messaggi **nuovi** dopo la rimozione sono rifiutati |
| **SYS-RECEPTION-012** | Aggiunta a lista: **nessuna** retro-consegna di messaggi precedentemente rifiutati |
| **SYS-RECEPTION-013** | Nuovo account: lista vuota di default (nessuno può scrivere finché non si aggiunge qualcuno) |
| **SYS-RECEPTION-014** | Filtro sempre attivo — **nessun** flag globale enable/disable a livello utente o piattaforma |
| **SYS-RECEPTION-018** | Stesso gate documentato per recapito **federato** (bridge XMPP/Matrix fase B): prima di materializzare copia ingresso su Alfred, verificare allow list del destinatario; stesso silenzio verso mittente esterno |

### SHOULD

| ID | Promessa |
|----|----------|
| **SYS-RECEPTION-019** | Lista ordinata per `display_name` del profilo consentito (join `profiles`) |

### MUST NOT

| ID | Promessa |
|----|----------|
| **SYS-RECEPTION-021** | Errore RPC, codice errore o messaggio «bloccato» / «rifiutato» verso il mittente |
| **SYS-RECEPTION-022** | Usare tabella `contacts` come fonte o proxy dell'allow list |
| **SYS-RECEPTION-023** | Materializzare copia destinatario su rifiuto (anche temporanea o «nascosta») |
| **SYS-RECEPTION-024** | Retro-consegnare messaggi rifiutati quando si aggiunge un profilo alla lista |
| **SYS-RECEPTION-025** | Eliminare dall'archivio messaggi già ricevuti quando si rimuove qualcuno dalla lista |
| **SYS-RECEPTION-026** | Toggle globale on/off della funzionalità allow list |
| **SYS-RECEPTION-027** | Mostrare al mittente che il destinatario usa un filtro di ricezione |
| **SYS-RECEPTION-028** | `GRANT EXECUTE` su `is_sender_allowed_for_reception` al ruolo `authenticated` — helper solo per RPC `SECURITY DEFINER` interne |

---

## 3. Contratto

### Gate recapito (internal)

```
send_message_to_profile
  → INSERT copia mittente (livello ✓)
  → SE EXISTS reception_allowlist(owner=dest, allowed=mittente):
       INSERT copia destinatario
       UPDATE mittente delivered_at = now()  (livello ✓✓)
       outbox status = completed
     ALTRIMENTI:
       skip copia destinatario
       delivered_at resta null
       outbox status = completed (payload opz. reception_rejected)
  → RETURN copia mittente
```

Helper interno: `is_sender_allowed_for_reception(p_owner_id, p_sender_profile_id) boolean` — `SECURITY DEFINER`, usata **solo** da RPC invio e futuro bridge.

Vedi [contracts/schema.md](../../contracts/schema.md) · [SYS-MAILBOX](./SYS-MAILBOX.md) SYS-MAILBOX-020.

---

## 5. Tracciabilità

| SYS-ID | Verifica |
|------------------------|----------|
| SYS-RECEPTION-001–004 | `supabase/tests/reception_allowlist_schema_smoke.sql` |
| SYS-RECEPTION-005–010 | `supabase/tests/reception_allowlist_gate_smoke.sql` |
| SYS-RECEPTION-007 | `reception_allowlist_gate_smoke.sql` — lista vuota |
| SYS-RECEPTION-011–012 | `reception_allowlist_gate_smoke.sql` |
| SYS-RECEPTION-005–009 | `bash scripts/test.sh integration` |
| SYS-RECEPTION-028 | `supabase/tests/rpc_helper_security_smoke.sql` |

Gate: `bash scripts/check-spec-sync.sh` · `cd client && bash scripts/verify.sh`

---

## 6. Riferimenti

- [registry.md](../../registry.md)
- [SURF-ALLOWLIST.md](../../surfaces/SURF-ALLOWLIST.md) · [SURF-PEER-PROFILE.md](../../surfaces/SURF-PEER-PROFILE.md)
- [contracts/schema.md](../../contracts/schema.md) · [contracts/rpc.md](../../contracts/rpc.md)
