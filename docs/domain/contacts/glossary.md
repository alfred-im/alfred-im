# Glossario — contesto contacts

**Bounded context:** `contacts`  
**Ultima revisione:** 2026-09-13  
**Promesse SDD:** [PROM-PERSONAL-CONTACTS](../../specs/promises/product/PROM-PERSONAL-CONTACTS.md), [SYS-CONTACTS](../../specs/promises/system/SYS-CONTACTS.md)  
**Amend:** rubrica solo `address` — distillazione TEMP §7

---

## Linguaggio ubiquo

| Termine | Definizione |
|---------|-------------|
| **Rubrica** | Lista personale contatti scoped per account — scorciatoie opzionali, non prerequisito per messaggistica. |
| **Contact** | Voce rubrica: **solo** `address` text lowercase — UNIQUE `(archive_user_id, address)`. |
| **address** | Indirizzo IM del contatto: `username` bare o `user@server`. Unico campo identità in rubrica. |
| **ArchiveUser** | Utente in focus; rubrica scoped all'account corrente. |
| **Profile search** | Ricerca profili Alfred per aggiunta (`search_profiles` — soglia minima caratteri, limite risultati). |
| **get_profiles** | Batch presentazione nome/avatar contatti — **non** persistito in `contacts`. |
| **Filtered contacts** | Sottoinsieme locale per nome/indirizzo via filtro lista ([PROM-LIST-FILTER](../../specs/promises/product/PROM-LIST-FILTER.md)). |
| **Compose shortcut** | Avvio conversazione da contatto verso navigation con `peer_address`. |
| **Peer profile overlay** | Scheda identità peer da tap avatar — **qualsiasi** indirizzo valido ([PROM-PEER-PROFILE](../../specs/promises/product/PROM-PEER-PROFILE.md)). |

---

## Confini

| Contesto | Relazione |
|----------|-----------|
| **profile** | `get_profiles(addresses[])` per presentazione; `search_profiles` per aggiunta. |
| **reception** | Allow list **separata** (`allowed_address`) — rubrica non implica consenso ricezione. |
| **messaging** | Inbox deriva solo da archivio messaggi; invio sempre address-based. |
| **navigation** | «Scrivi» da rubrica restituisce `peer_address` al chiamante. |
| **multi-account** | Rubrica scoped all'account in focus; ricreata al cambio focus. |

---

## Invarianti

1. Rubrica non abilita né blocca invio/ricezione messaggi.
2. Aggiunta contatto non crea conversazione in inbox.
3. Nessun id contatto richiesto per invio messaggio.
4. Dopo aggiunta/rimozione contatto → rubrica ricaricata.
5. Lookup contatto per `address` — un solo campo identità.
6. **Nessun** snapshot nome/avatar in `contacts` — presentazione via `get_profiles`.
7. Overlay peer disponibile per **qualsiasi** indirizzo, incluso `user@other-server`.
