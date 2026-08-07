# Glossario — contesto profile

**Bounded context:** `profile`  
**Ultima revisione:** 2026-07-27  
**Promesse SDD:** [PROM-PROFILE-IDENTITY](../../specs/promises/product/PROM-PROFILE-IDENTITY.md), [SYS-PROFILE](../../specs/promises/system/SYS-PROFILE.md)

---

## Linguaggio ubiquo

| Termine | Definizione |
|---------|-------------|
| **Profile summary** | Identità pubblica: id, nome, username, avatar, copertina, pronomi, tipo account. |
| **User profile** | Profilo completo proprio: summary + bio + timestamp. |
| **Public profile fields** | Campi esposti in query batch identità pubblica. |
| **Own profile edit** | Modifica campi propri (nome, bio, pronomi, avatar) — username read-only. |
| **Avatar upload** | Caricamento immagine profilo con limite dimensione; URL pubblico. |
| **Profile refresh** | Dopo save: allineamento identità in sessione e manifest multi-account. |
| **Profile identity lines** | Nome, username, pronomi — riusato in inbox, sidebar, liste. |

---

## Confini

| Contesto | Relazione |
|----------|-----------|
| **auth** | Profilo proprio da sessione; refresh dopo modifica. |
| **multi-account** | Snapshot profilo in manifest account aperti. |
| **messaging** | Peer inbox: campi profilo da anteprima inbox. |
| **peer-profile** | Surfaccia overlay su altri utenti — comandi delegati, non in questo contesto. |

---

## Invarianti

1. Email mai esposta in ricerca, rubrica o inbox pubblica.
2. Username non modificabile da schermata profilo proprio (scope attuale).
3. Stringhe opzionali (bio, pronomi) → null se vuote dopo trim.
4. Un solo modello identità pubblica in tutta l'UI.
