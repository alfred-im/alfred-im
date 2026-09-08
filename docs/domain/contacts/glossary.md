# Glossario — contesto contacts

**Bounded context:** `contacts`  
**Ultima revisione:** 2026-09-08  
**Promesse SDD:** [PROM-PERSONAL-CONTACTS](../../specs/promises/product/PROM-PERSONAL-CONTACTS.md), [SYS-CONTACTS](../../specs/promises/system/SYS-CONTACTS.md)

---

## Linguaggio ubiquo

| Termine | Definizione |
|---------|-------------|
| **Rubrica** | Lista personale contatti scoped per account — scorciatoie opzionali, non prerequisito per messaggistica. |
| **Contact** | Voce rubrica: nome visualizzato, snapshot avatar opzionale, riferimento locale o indirizzo federato. |
| **Contatto locale** | `linked_profile_id` valorizzato — profilo Alfred sulla stessa istanza. |
| **Contatto federato** | `external_address` valorizzato (`user@server`) — destinazione Gotham; compose da rubrica non supportato finché la federazione non è live. |
| **ArchiveUser** | Utente in focus; rubrica scoped all'account corrente. |
| **Profile search** | Ricerca profili Alfred per aggiunta locale (soglia minima caratteri, limite risultati). |
| **Filtered contacts** | Sottoinsieme locale per nome via filtro lista ([PROM-LIST-FILTER](../../specs/promises/product/PROM-LIST-FILTER.md)). |
| **Compose shortcut** | Avvio conversazione da contatto locale verso navigation. |
| **Peer profile overlay** | Scheda identità peer da tap avatar contatto locale ([PROM-PEER-PROFILE](../../specs/promises/product/PROM-PEER-PROFILE.md)). |

---

## Confini

| Contesto | Relazione |
|----------|-----------|
| **profile** | Identità pubblica per ricerca e snapshot locale. |
| **reception** | Allow list **separata** — rubrica non implica consenso ricezione. |
| **messaging** | Inbox deriva solo da archivio messaggi; invio sempre address-based. |
| **navigation** | «Scrivi» da rubrica restituisce peer conversazione al chiamante. |
| **multi-account** | Rubrica scoped all'account in focus; ricreata al cambio focus. |

---

## Invarianti

1. Rubrica non abilita né blocca invio/ricezione messaggi.
2. Aggiunta contatto non crea conversazione in inbox.
3. Nessun id contatto richiesto per invio messaggio.
4. Dopo aggiunta/rimozione contatto → rubrica ricaricata.
5. Lookup contatto per profilo considera solo contatti con `linked_profile_id`.
6. Contatti federati: nessun overlay peer al tap avatar.
