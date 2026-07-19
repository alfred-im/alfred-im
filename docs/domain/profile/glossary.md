# Glossario — contesto profile

**Bounded context:** `profile`  
**Ultima revisione:** 2026-07-19  
**Promesse SDD:** [PROM-PROFILE-IDENTITY](../../specs/promises/product/PROM-PROFILE-IDENTITY.md), [PROM-PEER-PROFILE](../../specs/promises/product/PROM-PEER-PROFILE.md), [SYS-PROFILE](../../specs/promises/system/SYS-PROFILE.md)

---

## Linguaggio ubiquo

| Termine | Definizione |
|---------|-------------|
| **Profile summary** | Identità pubblica: id, nome, username, avatar, pronomi, tipo account. |
| **User profile** | Profilo completo proprio: summary + bio + timestamp. |
| **Public profile fields** | Campi esposti in query batch identità pubblica. |
| **Own profile edit** | Modifica campi propri (nome, bio, pronomi, avatar) — username read-only. |
| **Avatar upload** | Caricamento immagine profilo con limite dimensione; URL pubblico. |
| **Profile refresh** | Dopo save: allineamento identità in sessione e manifest multi-account. |
| **Peer profile overlay** | Scheda identità peer con azioni allow/rubrica/chat/share. |
| **Hydrate profile** | Completamento campi peer mancanti da server. |
| **Profile identity lines** | Nome, username, pronomi — riusato in inbox, sidebar, liste. |

---

## Confini

| Contesto | Relazione |
|----------|-----------|
| **auth** | Profilo proprio da sessione; refresh dopo modifica. |
| **multi-account** | Snapshot profilo in manifest account aperti. |
| **contacts** | Overlay peer: toggle rubrica. |
| **reception** | Overlay peer: toggle allow list. |
| **navigation** | «Inizia a chattare» → apertura conversazione. |
| **shareable-link** | Condividi profilo peer da overlay. |
| **messaging** | Peer inbox: campi profilo da anteprima inbox. |

---

## Invarianti

1. Email mai esposta in ricerca, rubrica o inbox pubblica.
2. Username non modificabile da schermata profilo proprio (scope attuale).
3. Stringhe opzionali (bio, pronomi) → null se vuote dopo trim.
4. Overlay peer non si apre per profilo proprio.
5. Allow e rubrica nell'overlay sono indipendenti e immediati (no dialog).
6. Un solo modello identità pubblica in tutta l'UI.
