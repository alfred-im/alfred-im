# SURF-PEER-PROFILE — Overlay profilo peer

| Campo | Valore |
|-------|--------|
| **Superficie ID** | `SURF-PEER-PROFILE` |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-09 |
| **Promesse** | [PROM-PEER-PROFILE](../promises/product/PROM-PEER-PROFILE.md), [PROM-OVERLAY-DISMISS](../promises/product/PROM-OVERLAY-DISMISS.md), [SYS-CONTACTS](../promises/system/SYS-CONTACTS.md), [SYS-RECEPTION](../promises/system/SYS-RECEPTION.md) |
| **PR** | #163, #176 |

Binding UX overlay fullscreen al tap avatar di un account Alfred altrui: identità pubblica, toggle allow list, azione rubrica, CTA «Inizia a chattare» sticky in basso.

---

## 1. Superficie

| Elemento | Valore |
|----------|--------|
| Entry | `showPeerProfileOverlay` — `client/lib/widgets/peer_profile_overlay.dart` |
| Widget | `PeerProfileOverlay`, `ProfileAvatar.onTap` |
| Controller | `ContactsController`, `ReceptionAllowlistController` (account in focus) |

---

## 2. Promesse SURFACE

### MUST

| ID | Promessa |
|----|----------|
| **SURF-PEER-PROFILE-001** | Tap avatar peer Alfred → overlay fullscreen (`showPeerProfileOverlay`) |
| **SURF-PEER-PROFILE-002** | Overlay mostra: avatar grande, `display_name`, `@username` se presente, pronomi se presenti |
| **SURF-PEER-PROFILE-003** | Switch **Allow** («Consenti messaggi») ↔ `reception_allowlist` del focus — semantica [SYS-RECEPTION](../promises/system/SYS-RECEPTION.md) invariata |
| **SURF-PEER-PROFILE-004** | Pulsante rubrica «Aggiungi alla rubrica» / «Rimuovi dalla rubrica» ↔ `contacts` internal — semantica [SYS-CONTACTS](../promises/system/SYS-CONTACTS.md) invariata |
| **SURF-PEER-PROFILE-005** | Allow e rubrica **indipendenti** — stato UI separato |
| **SURF-PEER-PROFILE-006** | Allow e rubrica: azione **immediata**, **senza** dialog di conferma |
| **SURF-PEER-PROFILE-007** | Profilo proprio (`profile.id == auth.userId`): **non** aprire overlay peer |
| **SURF-PEER-PROFILE-008** | Punti attivazione: tile inbox (solo avatar), header chat, autore messaggio gruppo, lista «Persone consentite», rubrica (solo internal) |
| **SURF-PEER-PROFILE-009** | `ContactsController.contactForProfileId` + `removeInternalByProfileId` per rimozione rubrica da overlay |
| **SURF-PEER-PROFILE-010** | `ReceptionAllowlistController.removeByProfileId` per toggle Allow off da overlay |
| **SURF-PEER-PROFILE-011** | Controller legati all'account in **focus** |
| **SURF-PEER-PROFILE-015** | CTA «Inizia a chattare» fisso in basso al centro — **non** nello scroll con Allow/rubrica |
| **SURF-PEER-PROFILE-016** | Tap CTA → chiude overlay e apre chat peer sull'account in focus (`ChatPeer.fromProfile`) |

### SHOULD

| ID | Promessa |
|----|----------|
| **SURF-PEER-PROFILE-012** | Transizione fade + slide leggero all'apertura overlay |
| **SURF-PEER-PROFILE-013** | Chiusura: pulsante ✕ e tap su barrier |
| **SURF-PEER-PROFILE-014** | `ProfileAvatar` accetta `onTap` opzionale con feedback ripple circolare |

### MUST NOT

| ID | Promessa |
|----|----------|
| **SURF-PEER-PROFILE-020** | Confondere Allow (ricezione) con rubrica (scorciatoia) |
| **SURF-PEER-PROFILE-021** | Dialog di conferma su toggle Allow o azione rubrica nell'overlay |
| **SURF-PEER-PROFILE-022** | Esporre email del peer |
| **SURF-PEER-PROFILE-023** | Nuove RPC o tabelle — solo PostgREST esistente |
| **SURF-PEER-PROFILE-024** | Overlay per contatti rubrica **esterni** (senza `linked_profile_id`) |

---

## 4. Tracciabilità

| SURF-ID | Verifica |
|--------------------|----------|
| SURF-PEER-PROFILE-003 | `reception_allowlist_controller_test.dart` — `removeByProfileId` |
| SURF-PEER-PROFILE-004 | `contacts_controller_test.dart` — `contactForProfileId`, `removeInternalByProfileId` |
| SURF-PEER-PROFILE-007 | `peer_profile_overlay_test.dart` — skip self |
| SURF-PEER-PROFILE-002 | `peer_profile_overlay_test.dart` — widget smoke |
| SURF-PEER-PROFILE-011 | `main.dart` — proxy provider focus |
| SURF-PEER-PROFILE-015, 016 | `peer_profile_overlay_test.dart` — CTA sticky; tap apre conversazione |

Gate: `bash scripts/check-spec-sync.sh` + `cd client && bash scripts/verify.sh`

---

## 5. Riferimenti

- [SYS-RECEPTION.md](../promises/system/SYS-RECEPTION.md)
- [SYS-CONTACTS.md](../promises/system/SYS-CONTACTS.md)
- [SURF-ALLOWLIST.md](./SURF-ALLOWLIST.md)
- [registry.md](../registry.md)
