# Glossario — contesto profile

**Bounded context:** `profile`  
**Ultima revisione:** 2026-09-13  
**Promesse SDD:** [PROM-PROFILE-IDENTITY](../../specs/promises/product/PROM-PROFILE-IDENTITY.md), [SYS-PROFILE](../../specs/promises/system/SYS-PROFILE.md), [PROM-PEER-PROFILE](../../specs/promises/product/PROM-PEER-PROFILE.md)  
**Amend:** `get_profiles(addresses[])` — distillazione TEMP §7

---

## Linguaggio ubiquo

| Termine | Definizione |
|---------|-------------|
| **Profile summary** | Identità pubblica per presentazione: indirizzo, nome, avatar, copertina, pronomi, tipo account. |
| **get_profiles** | RPC batch `get_profiles(p_addresses text[])` → setof `{ address, display_name, avatar_url, … }`. Profilo pubblico **sempre** — **non** gated da allow list. |
| **User profile** | Profilo completo proprio: summary + bio + timestamp. |
| **Public profile fields** | Campi esposti da `get_profiles` — risposta RPC, non INSERT in `profiles` per peer remoti. |
| **Own profile edit** | Modifica campi propri (nome, bio, pronomi, avatar) — username read-only. |
| **Avatar upload** | Caricamento immagine profilo con limite dimensione; URL pubblico. |
| **Profile refresh** | Dopo save: allineamento identità in sessione e manifest multi-account. |
| **Profile identity lines** | Nome, indirizzo, pronomi — riusato in inbox, sidebar, liste via `get_profiles`. |
| **Fallback indirizzo** | Se `get_profiles` non restituisce dati (peer remoto pre-wire): mostra indirizzo grezzo. |

---

## Confini

| Contesto | Relazione |
|----------|-----------|
| **auth** | Profilo proprio da sessione; refresh dopo modifica. |
| **multi-account** | Snapshot profilo in manifest account aperti. |
| **messaging** | Presentazione peer inbox/header: `get_profiles([peer_address])`. |
| **peer-profile** | Surfaccia overlay su altri utenti — comandi delegati, non in questo contesto. |
| **federation** | Profilo remoto = interazione federata; risposta RPC, non profilo shadow locale. |

---

## Invarianti

1. Email mai esposta in ricerca, rubrica o inbox pubblica.
2. Username non modificabile da schermata profilo proprio (scope attuale).
3. Stringhe opzionali (bio, pronomi) → null se vuote dopo trim.
4. Un solo modello identità pubblica in tutta l'UI — batch `get_profiles`.
5. `get_profiles` **non** gated da allow list — allow list governa recapito messaggi, non visibilità profilo.
6. Nessun profilo shadow in `profiles` per peer remoti.
