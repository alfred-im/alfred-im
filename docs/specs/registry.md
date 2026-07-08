# Registro promesse — Alfred

**Ultima revisione**: 2026-07-08  
**Metodo**: [README.md](./README.md) (SDD)

Indice unico di promesse **SYSTEM**, **PRODUCT** e **SURFACE**. Nessun altro layer contrattuale.

Legenda stato: `draft` | `approved` | `implemented` | `deprecated` | `superseded`

---

## SYSTEM — piattaforma

Dettaglio implementativo (DDL, firme RPC, RLS): **[contracts/schema.md](./contracts/schema.md)** · **[contracts/rpc.md](./contracts/rpc.md)**

| Promessa ID | Titolo | Stato | File |
|-------------|--------|-------|------|
| **SYS-MAILBOX** | Archivio per owner, invio, inbox on-read, spunte | `implemented` | [SYS-MAILBOX.md](./promises/system/SYS-MAILBOX.md) |
| **SYS-GROUP** | Account gruppo, partecipazione, erogazione | `implemented` | [SYS-GROUP.md](./promises/system/SYS-GROUP.md) |
| **SYS-PROFILE** | Tabella `profiles`, avatar, RPC profilo | `implemented` | [SYS-PROFILE.md](./promises/system/SYS-PROFILE.md) |
| **SYS-CONTACTS** | Rubrica `contacts`, `search_profiles` | `implemented` | [SYS-CONTACTS.md](./promises/system/SYS-CONTACTS.md) |
| **SYS-RECEPTION** | Allow list ricezione, gate `send_message_to_profile` | `implemented` | [SYS-RECEPTION.md](./promises/system/SYS-RECEPTION.md) |

---

## PRODUCT — promesse riusabili

| Promessa ID | Titolo | Stato | File |
|-------------|--------|-------|------|
| **PROM-LIST-FILTER** | Filtro locale + ricerca on-demand (lente) | `implemented` | [PROM-LIST-FILTER.md](./promises/product/PROM-LIST-FILTER.md) |
| **PROM-MULTI-ACCOUNT** | Manifest, focus, una GoTrue attiva | `implemented` | [PROM-MULTI-ACCOUNT.md](./promises/product/PROM-MULTI-ACCOUNT.md) |
| **PROM-PROFILE-IDENTITY** | `ProfileSummary`, widget identità | `implemented` | [PROM-PROFILE-IDENTITY.md](./promises/product/PROM-PROFILE-IDENTITY.md) |
| **PROM-PERSONAL-CONTACTS** | Rubrica isolata da inbox/allow list | `implemented` | [PROM-PERSONAL-CONTACTS.md](./promises/product/PROM-PERSONAL-CONTACTS.md) |
| **PROM-RECEPTION-FILTER** | Filtro ricezione sempre attivo, rifiuto silenzioso | `implemented` | [PROM-RECEPTION-FILTER.md](./promises/product/PROM-RECEPTION-FILTER.md) |
| **PROM-PEER-PROFILE** | Overlay profilo peer (tap avatar) | `implemented` | [PROM-PEER-PROFILE.md](./promises/product/PROM-PEER-PROFILE.md) |
| **PROM-OVERLAY-DISMISS** | Chiusura overlay fullscreen | `implemented` | [PROM-OVERLAY-DISMISS.md](./promises/product/PROM-OVERLAY-DISMISS.md) |
| **PROM-CHAT-PEER-KEY** | Chat per `peer_profile_id`, no `thread_id` | `implemented` | [PROM-CHAT-PEER-KEY.md](./promises/product/PROM-CHAT-PEER-KEY.md) |
| **PROM-OUTBOUND-SEND** | Coda invio + merge optimistic | `implemented` | [PROM-OUTBOUND-SEND.md](./promises/product/PROM-OUTBOUND-SEND.md) |
| **PROM-MESSAGE-STATUS** | Spunte da `delivered_at`/`read_at` | `implemented` | [PROM-MESSAGE-STATUS.md](./promises/product/PROM-MESSAGE-STATUS.md) |
| **PROM-REALTIME-OWNER** | Realtime filtrato su `owner_id` | `implemented` | [PROM-REALTIME-OWNER.md](./promises/product/PROM-REALTIME-OWNER.md) |
| **PROM-GROUP-AUTHOR-DISPLAY** | Autore contenuto in chat gruppo | `implemented` | [PROM-GROUP-AUTHOR-DISPLAY.md](./promises/product/PROM-GROUP-AUTHOR-DISPLAY.md) |
| **PROM-GROUP-TICKS** | Spunte limitate al rapporto con il gruppo | `implemented` | [PROM-GROUP-TICKS.md](./promises/product/PROM-GROUP-TICKS.md) |

---

## SURFACE — binding per schermata

| Superficie ID | Titolo | Stato | Promesse principali | File |
|---------------|--------|-------|---------------------|------|
| **SURF-AUTH** | Overlay login/registrazione | `implemented` | PROM-MULTI-ACCOUNT | [SURF-AUTH.md](./surfaces/SURF-AUTH.md) |
| **SURF-APP-SHELL** | `HomeScreen` sempre visibile | `implemented` | PROM-MULTI-ACCOUNT | (in SURF-AUTH) |
| **SURF-ACCOUNT-SIDEBAR** | Manifest account in sidebar | `implemented` | PROM-MULTI-ACCOUNT, PROM-PROFILE-IDENTITY | [SURF-ACCOUNT-SIDEBAR.md](./surfaces/SURF-ACCOUNT-SIDEBAR.md) |
| **SURF-INBOX** | Lista conversazioni | `implemented` | PROM-LIST-FILTER, PROM-REALTIME-OWNER | [SURF-INBOX.md](./surfaces/SURF-INBOX.md) |
| **SURF-CHAT** | Conversazione 1:1 | `implemented` | PROM-CHAT-PEER-KEY, PROM-MESSAGE-STATUS, PROM-OUTBOUND-SEND | [SURF-CHAT.md](./surfaces/SURF-CHAT.md) |
| **SURF-CONTACTS** | Rubrica | `implemented` | PROM-LIST-FILTER, PROM-PERSONAL-CONTACTS | [SURF-CONTACTS.md](./surfaces/SURF-CONTACTS.md) |
| **SURF-ALLOWLIST** | Persone consentite | `implemented` | PROM-LIST-FILTER, PROM-RECEPTION-FILTER | [SURF-ALLOWLIST.md](./surfaces/SURF-ALLOWLIST.md) |
| **SURF-PROFILE** | Modifica profilo proprio | `implemented` | PROM-PROFILE-IDENTITY, SYS-PROFILE | [SURF-PROFILE.md](./surfaces/SURF-PROFILE.md) |
| **SURF-PEER-PROFILE** | Scheda profilo peer | `implemented` | PROM-PEER-PROFILE, PROM-OVERLAY-DISMISS | [SURF-PEER-PROFILE.md](./surfaces/SURF-PEER-PROFILE.md) |
| **SURF-GROUP-SHELL** | Shell account gruppo | `implemented` | PROM-MULTI-ACCOUNT, SYS-GROUP | [SURF-GROUP-SHELL.md](./surfaces/SURF-GROUP-SHELL.md) |
| **SURF-GROUP-CONVERSATION** | Chat gruppo + erogazione UI | `implemented` | PROM-GROUP-AUTHOR-DISPLAY, PROM-GROUP-TICKS | [SURF-GROUP-CONVERSATION.md](./surfaces/SURF-GROUP-CONVERSATION.md) |

---

## Backlog (non ancora distillato)

| ID proposto | Classe | Contenuto |
|-------------|--------|-----------|
| PROM-BOTTOM-ANCHOR | PRODUCT | Lista messaggi agganciata al fondo — evidenza [conversation-bottom-anchor.md](../design/conversation-bottom-anchor.md) |
| BRIDGE-* | SYSTEM | Consumer outbox federato (post-Alpha) |
