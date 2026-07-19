# Comandi ed eventi — contesto profile

**Ultima revisione:** 2026-07-19  
**UML:** [docs/model/uml/profile/](../../model/uml/profile/)

---

## Comandi — profilo proprio

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `SaveProfile` | Utente | Salva campi profilo proprio (nome, bio, pronomi, avatar). |
| `UploadAvatar` | Utente | Carica nuova immagine avatar. |
| `RefreshAuthProfile` | Policy (post save/upload) | Allinea identità in sessione e manifest multi-account. |
| `FindByUsername` | Utente / Policy | Risolve profilo per username (compose, link). |
| `FetchSummariesByIds` | Policy | Lookup batch profili pubblici per liste. |
| `FindById` | Policy | Lookup singolo profilo per arricchimento parziale. |

---

## Comandi — overlay peer

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `OpenPeerProfile` | Utente | Mostra scheda identità peer. |
| `HydratePeerProfile` | Policy (apertura overlay) | Completa campi mancanti da server. |
| `ToggleAllowMessages` | Utente | Consente/revoca recapito da peer (contesto reception). |
| `ToggleRubrica` | Utente | Aggiunge/rimuove peer dalla rubrica (contesto contacts). |
| `StartChatFromProfile` | Utente | Avvia conversazione con peer dall'overlay. |
| `ShareProfileLink` | Utente | Condivide link profilo peer. |
| `ClosePeerProfile` | Utente | Chiude overlay peer. |

---

## Eventi

| Evento | Descrizione |
|--------|-------------|
| `ProfileSaved` | Profilo proprio aggiornato con successo. |
| `ProfileSaveFailed` | Salvataggio profilo fallito. |
| `AvatarUploaded` | Avatar caricato; URL disponibile. |
| `AvatarUploadFailed` | Upload avatar fallito (dimensione o rete). |
| `AuthProfileRefreshed` | Identità sessione e manifest allineati. |
| `PeerProfileOpened` | Overlay peer visibile. |
| `PeerProfileHydrated` | Profilo peer completo da server. |
| `AllowToggled` | Allow list aggiornata da overlay. |
| `RubricaToggled` | Rubrica aggiornata da overlay. |
| `ConversationOpenRequested` | Richiesta apertura chat verso peer. |

---

## Policy

| Policy | Trigger | Azione |
|--------|---------|--------|
| **No self overlay** | `OpenPeerProfile` su profilo proprio | Ignorato |
| **Username read-only** | `SaveProfile` | Username non modificabile (scope attuale) |
| **Campi opzionali vuoti** | `SaveProfile` | Bio/pronomi → null se vuoti dopo trim |
| **Toggle immediati** | Allow / rubrica in overlay | Nessun dialog di conferma |

---

## Tracciabilità SDD

| Elemento | Promessa |
|----------|----------|
| `ProfileSummary` unificato | PROM-PROFILE-IDENTITY-001, 002 |
| Refresh dopo save | PROM-PROFILE-IDENTITY-003 |
| Overlay apertura/contenuto | PROM-PEER-PROFILE-001–004 |
| Toggle allow / rubrica | PROM-PEER-PROFILE-005–008 |
| CTA chat | PROM-PEER-PROFILE-013, 014 |
| Username read-only | PROM-PROFILE-IDENTITY-021 |
