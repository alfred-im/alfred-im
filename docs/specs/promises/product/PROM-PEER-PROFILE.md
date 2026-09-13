# PROM-PEER-PROFILE — Scheda profilo peer in overlay

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `PROM-PEER-PROFILE` |
| **Classe** | PRODUCT |
| **Status** | `approved` |
| **Ultima revisione** | 2026-09-13 |
| **PR origine** | #163, #176 |
| **Amend** | address-based + `get_profiles` — distillazione [TEMP-chat-peer-key-address-drift.md](../../../tmp/TEMP-chat-peer-key-address-drift.md) §7 |

Promessa di prodotto: tap avatar peer Alfred → overlay fullscreen con identità pubblica, toggle allow list, azione rubrica e CTA «Inizia a chattare» — **indipendenti** e **immediati**. Identità keyed su **`peer_address`**; presentazione via **`get_profiles(addresses[])`** batch.

---

## 1. Problema / obiettivo

In diversi punti della piattaforma l'utente vede l'avatar di un altro account Alfred. Al tap sull'avatar si apre una modale con identità pubblica e due azioni distinte: consentire ricezione messaggi ([PROM-RECEPTION-FILTER](./PROM-RECEPTION-FILTER.md)) e aggiungere/rimuovere dalla rubrica ([PROM-PERSONAL-CONTACTS](./PROM-PERSONAL-CONTACTS.md)).

Presentazione: `get_profiles([peer_address])` — profilo pubblico **sempre** (consent-first); allow list governa **recapito messaggi**, non visibilità profilo. Fallback → indirizzo grezzo. Nessun profilo shadow in `profiles` per peer remoti.

---

## 2. Promesse

### MUST — apertura e contenuto

| ID | Promessa |
|----|----------|
| **PROM-PEER-PROFILE-001** | Tap avatar peer Alfred → overlay fullscreen profilo peer |
| **PROM-PEER-PROFILE-002** | Overlay mostra: avatar grande, `display_name`, indirizzo (`@username` o `user@server`), pronomi se presenti — dati da `get_profiles`; fallback indirizzo grezzo |
| **PROM-PEER-PROFILE-003** | Profilo proprio (`peer_address` == indirizzo account in focus): **non** aprire overlay peer |
| **PROM-PEER-PROFILE-004** | Punti attivazione: tile inbox (solo avatar), header chat, autore messaggio gruppo, lista «Persone consentite», rubrica — **qualsiasi** indirizzo valido, incluso `user@other-server` |

### MUST — azioni

| ID | Promessa |
|----|----------|
| **PROM-PEER-PROFILE-005** | Switch **Allow** («Consenti messaggi») ↔ `reception_allowlist` del focus per `allowed_address` — semantica [PROM-RECEPTION-FILTER](./PROM-RECEPTION-FILTER.md) |
| **PROM-PEER-PROFILE-006** | Pulsante rubrica «Aggiungi alla rubrica» / «Rimuovi dalla rubrica» ↔ `contacts.address` — semantica [PROM-PERSONAL-CONTACTS](./PROM-PERSONAL-CONTACTS.md) |
| **PROM-PEER-PROFILE-007** | Allow e rubrica **indipendenti** — stato UI separato |
| **PROM-PEER-PROFILE-008** | Allow e rubrica: azione **immediata**, **senza** dialog di conferma |
| **PROM-PEER-PROFILE-009** | Controller legati all'account in **focus** — [PROM-MULTI-ACCOUNT](./PROM-MULTI-ACCOUNT.md) |
| **PROM-PEER-PROFILE-013** | Pulsante fisso «Inizia a chattare» in basso nell'overlay peer — fuori dall'area scrollabile |
| **PROM-PEER-PROFILE-014** | Tap «Inizia a chattare» → chiude overlay e apre chat con `peer_address` sull'account in focus — stesso effetto di scorciatoia compose da rubrica ([PROM-PERSONAL-CONTACTS](./PROM-PERSONAL-CONTACTS.md)) |
| **PROM-PEER-PROFILE-015** | `get_profiles` **non** gated da allow list — profilo pubblico sempre |

### SHOULD

| ID | Promessa |
|----|----------|
| **PROM-PEER-PROFILE-010** | Transizione fade + slide leggero all'apertura overlay |
| **PROM-PEER-PROFILE-011** | Chiusura overlay: conforme a [PROM-OVERLAY-DISMISS](./PROM-OVERLAY-DISMISS.md) |
| **PROM-PEER-PROFILE-012** | `ProfileAvatar` accetta `onTap` opzionale con feedback ripple circolare |

### MUST NOT

| ID | Promessa |
|----|----------|
| **PROM-PEER-PROFILE-020** | Confondere Allow (ricezione) con rubrica (scorciatoia) |
| **PROM-PEER-PROFILE-021** | Dialog di conferma su toggle Allow o azione rubrica nell'overlay |
| **PROM-PEER-PROFILE-022** | Esporre email del peer |
| **PROM-PEER-PROFILE-023** | Escludere overlay per indirizzi `user@other-server` — deriva da modello UUID-centrico |
| **PROM-PEER-PROFILE-024** | Profilo shadow in `profiles` per peer remoti |
| **PROM-PEER-PROFILE-025** | Gate `get_profiles` su allow list del richiedente |

---

## 3. Modello (riferimento)

| Elemento | Artefatto |
|----------|-----------|
| Glossario / comandi surfaccia | [docs/domain/peer-profile/](../../../domain/peer-profile/) |
| Contesti delegati | [reception](../../../domain/reception/), [contacts](../../../domain/contacts/), [navigation](../../../domain/navigation/), [profile](../../../domain/profile/) |
| UML | [docs/model/uml/profile/seq-peer-profile-overlay.puml](../../../model/uml/profile/seq-peer-profile-overlay.puml) |
| Statechart client | **Nessuno** per overlay peer — delega a `ReceptionMachine`, `ContactsMachine`, `NavigationMachine` (vedi peer-profile README) |
| Overlay dismiss | [PROM-OVERLAY-DISMISS](./PROM-OVERLAY-DISMISS.md) |

**Implementazione (non vincolante):** [docs/guides/peer-profile.md](../../../guides/peer-profile.md) · binding: [SURF-PEER-PROFILE](../../surfaces/SURF-PEER-PROFILE.md)

---

## 4. Superfici conformi

| Superficie | Stato | File |
|------------|-------|------|
| SURF-INBOX | `approved` | [SURF-INBOX.md](../../surfaces/SURF-INBOX.md) — tap avatar tile |
| SURF-CONTACTS | `approved` | [SURF-CONTACTS.md](../../surfaces/SURF-CONTACTS.md) |
| SURF-ALLOWLIST | `approved` | [SURF-ALLOWLIST.md](../../surfaces/SURF-ALLOWLIST.md) |
| Chat header / gruppo | `approved` | `chat_panel.dart`, `message_author_header.dart` |

---

## 5. Tracciabilità

| PROM-ID | Verifica |
|---------|----------|
| PROM-PEER-PROFILE-005, 010 | `reception_allowlist_controller_test.dart` — `removeByAddress` |
| PROM-PEER-PROFILE-006, 009 | `contacts_controller_test.dart` — `contactForAddress`, `removeByAddress` |
| PROM-PEER-PROFILE-003 | `peer_profile_overlay_test.dart` — skip self |
| PROM-PEER-PROFILE-002, 008, 012, 015 | `peer_profile_overlay_test.dart` — widget smoke; `get_profiles` batch |
| PROM-PEER-PROFILE-009 | `main.dart` — proxy provider focus |
| PROM-PEER-PROFILE-011 | [PROM-OVERLAY-DISMISS](./PROM-OVERLAY-DISMISS.md) |
| PROM-PEER-PROFILE-013, 014 | `peer_profile_overlay_test.dart` — CTA visibile; tap apre conversazione |
| PROM-PEER-PROFILE-023, 024, 025 | Scenario federato — overlay con fallback indirizzo |

Gate: `bash scripts/check-spec-sync.sh` + `cd client && bash scripts/verify.sh`

---

## 6. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [registry.md](../../registry.md) | Indice promesse |
| [SURF-PEER-PROFILE](../../surfaces/SURF-PEER-PROFILE.md) | Binding superficie |
| [PROM-OVERLAY-DISMISS](./PROM-OVERLAY-DISMISS.md) | Chiusura overlay |
| [PROM-RECEPTION-FILTER](./PROM-RECEPTION-FILTER.md) | Semantica Allow |
| [PROM-PERSONAL-CONTACTS](./PROM-PERSONAL-CONTACTS.md) | Semantica rubrica |
| [PROM-SHAREABLE-LINK](./PROM-SHAREABLE-LINK.md) | Condividi profilo peer (overlay) |
| [PROM-CHAT-PEER-KEY](./PROM-CHAT-PEER-KEY.md) | Chiave conversazione `peer_address` |
