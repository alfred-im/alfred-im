# Glossario — contesto contacts

**Bounded context:** `contacts`  
**Ultima revisione:** 2026-07-19  
**Promesse SDD:** [PROM-PERSONAL-CONTACTS](../../specs/promises/product/PROM-PERSONAL-CONTACTS.md), [SYS-CONTACTS](../../specs/promises/system/SYS-CONTACTS.md)

---

## Linguaggio ubiquo

| Termine | Definizione |
|---------|-------------|
| **Rubrica** | Lista personale contatti scoped per account — scorciatoie opzionali, non prerequisito per messaggistica. |
| **Contact** | Voce rubrica: protocollo, nome visualizzato, snapshot avatar, riferimento internal o indirizzo esterno. |
| **Contact protocol** | `internal` (utente Alfred), `xmpp`, `matrix` — solo routing/salvataggio; non tipo chat in inbox. |
| **Internal contact** | Contatto collegato a profilo Alfred; snapshot nome e avatar al momento dell'aggiunta. |
| **External contact** | Indirizzo esterno + nome; federazione futura — compose da rubrica non supportato (scope attuale). |
| **Owner** | Utente in focus; rubrica scoped all'account corrente. |
| **Profile search** | Ricerca profili Alfred per aggiunta internal (soglia minima caratteri, limite risultati). |
| **Filtered contacts** | Sottoinsieme locale per nome via filtro lista ([PROM-LIST-FILTER](../../specs/promises/product/PROM-LIST-FILTER.md)). |
| **Compose shortcut** | Avvio conversazione da contatto internal verso navigation. |
| **Peer profile overlay** | Scheda identità peer da tap avatar contatto internal ([PROM-PEER-PROFILE](../../specs/promises/product/PROM-PEER-PROFILE.md)). |

---

## Confini

| Contesto | Relazione |
|----------|-----------|
| **profile** | Identità pubblica per ricerca e snapshot internal. |
| **reception** | Allow list **separata** — rubrica non implica consenso ricezione ([PROM-RECEPTION-FILTER-010](../../specs/promises/product/PROM-RECEPTION-FILTER.md)). |
| **messaging** | Inbox deriva solo da archivio messaggi; invio sempre address-based. |
| **navigation** | «Scrivi» da rubrica restituisce peer conversazione al chiamante. |
| **multi-account** | Rubrica scoped all'account in focus; ricreata al cambio focus. |

---

## Invarianti

1. Rubrica non abilita né blocca invio/ricezione messaggi.
2. Aggiunta contatto non crea conversazione in inbox.
3. Nessun id contatto richiesto per invio messaggio.
4. Dopo aggiunta/rimozione contatto → rubrica ricaricata.
5. Lookup contatto per profilo considera solo contatti internal collegati.
6. Contatti esterni: nessun overlay peer al tap avatar ([PROM-PEER-PROFILE-023](../../specs/promises/product/PROM-PEER-PROFILE.md)).
