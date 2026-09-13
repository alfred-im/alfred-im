# SURF-PEER-PROFILE — Overlay profilo peer

| Campo | Valore |
|-------|--------|
| **Superficie ID** | `SURF-PEER-PROFILE` |
| **Status** | `approved` |
| **Ultima revisione** | 2026-09-13 |
| **Promesse** | [PROM-PEER-PROFILE](../promises/product/PROM-PEER-PROFILE.md), [PROM-OVERLAY-DISMISS](../promises/product/PROM-OVERLAY-DISMISS.md), [PROM-SHAREABLE-LINK](../promises/product/PROM-SHAREABLE-LINK.md), [SYS-CONTACTS](../promises/system/SYS-CONTACTS.md), [SYS-RECEPTION](../promises/system/SYS-RECEPTION.md) |
| **PR** | #163, #176, #178 |
| **Amend** | address-based + `get_profiles` — distillazione TEMP §7 |

Binding UX overlay fullscreen al tap avatar di un account Alfred altrui: identità pubblica via `get_profiles([peer_address])`, toggle allow list per `allowed_address`, azione rubrica per `contacts.address`, CTA «Inizia a chattare» sticky in basso.

---

## 1. Superficie

| Elemento | Valore |
|----------|--------|
| Entry | `showPeerProfileOverlay` — `client/lib/widgets/peer_profile_overlay.dart` |
| Widget | `PeerProfileOverlay`, `ProfileAvatar.onTap` |
| Controller | `ContactsController`, `ReceptionAllowlistController` (account in focus) |
| Presentazione | `get_profiles([peer_address])` — fallback indirizzo grezzo |

---

## 2. Promesse SURFACE

### MUST

| ID | Promessa |
|----|----------|
| **SURF-PEER-PROFILE-001** | Tap avatar peer Alfred → overlay fullscreen (`showPeerProfileOverlay`) |
| **SURF-PEER-PROFILE-002** | Overlay mostra: avatar grande, `display_name`, indirizzo (`@username` o `user@server`), pronomi se presenti — da `get_profiles` |
| **SURF-PEER-PROFILE-003** | Switch **Allow** («Consenti messaggi») ↔ `reception_allowlist.allowed_address` del focus — semantica [SYS-RECEPTION](../promises/system/SYS-RECEPTION.md) |
| **SURF-PEER-PROFILE-004** | Pulsante rubrica «Aggiungi alla rubrica» / «Rimuovi dalla rubrica» ↔ `contacts.address` — semantica [SYS-CONTACTS](../promises/system/SYS-CONTACTS.md) |
| **SURF-PEER-PROFILE-005** | Allow e rubrica **indipendenti** — stato UI separato |
| **SURF-PEER-PROFILE-006** | Allow e rubrica: azione **immediata**, **senza** dialog di conferma |
| **SURF-PEER-PROFILE-007** | Profilo proprio (`peer_address` == indirizzo account in focus): **non** aprire overlay peer |
| **SURF-PEER-PROFILE-008** | Punti attivazione: tile inbox (solo avatar), header chat, autore messaggio gruppo, lista «Persone consentite», rubrica — **qualsiasi** indirizzo valido |
| **SURF-PEER-PROFILE-009** | `ContactsController.contactForAddress` + `removeByAddress` per rimozione rubrica da overlay |
| **SURF-PEER-PROFILE-010** | `ReceptionAllowlistController.removeByAddress` per toggle Allow off da overlay |
| **SURF-PEER-PROFILE-011** | Controller legati all'account in **focus** |
| **SURF-PEER-PROFILE-015** | CTA «Inizia a chattare» fisso in basso al centro — **non** nello scroll con Allow/rubrica |
| **SURF-PEER-PROFILE-016** | Tap CTA → chiude overlay e apre chat peer sull'account in focus (`ChatPeer` con `peer_address`) |
| **SURF-PEER-PROFILE-025** | Pulsante **Condividi** in alto a destra — share di sistema URL profilo `#indirizzo` — [PROM-SHAREABLE-LINK](../promises/product/PROM-SHAREABLE-LINK.md) |
| **SURF-PEER-PROFILE-026** | Condividi su profilo peer **utente e gruppo** — stesso layout |
| **SURF-PEER-PROFILE-027** | `get_profiles` **non** gated da allow list — profilo pubblico sempre |

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
| **SURF-PEER-PROFILE-023** | Profilo shadow in `profiles` per peer remoti |
| **SURF-PEER-PROFILE-024** | Escludere overlay per indirizzi `user@other-server` |
| **SURF-PEER-PROFILE-028** | Lookup allow/rubrica per UUID profilo — deriva pre-amend |

---

## 4. Tracciabilità

| SURF-ID | Verifica |
|--------------------|----------|
| SURF-PEER-PROFILE-003 | `reception_allowlist_controller_test.dart` — `removeByAddress` |
| SURF-PEER-PROFILE-004 | `contacts_controller_test.dart` — `contactForAddress`, `removeByAddress` |
| SURF-PEER-PROFILE-007 | `peer_profile_overlay_test.dart` — skip self |
| SURF-PEER-PROFILE-002, 027 | `peer_profile_overlay_test.dart` — widget smoke; `get_profiles` |
| SURF-PEER-PROFILE-011 | `main.dart` — proxy provider focus |
| SURF-PEER-PROFILE-015, 016 | `peer_profile_overlay_test.dart` — CTA sticky; tap apre conversazione |
| SURF-PEER-PROFILE-025, 026 | `peer_profile_overlay_test.dart` — Condividi ([PROM-SHAREABLE-LINK](../promises/product/PROM-SHAREABLE-LINK.md)) |
| SURF-PEER-PROFILE-024 | Scenario federato — overlay con fallback indirizzo |

Gate: `bash scripts/check-spec-sync.sh` + `cd client && bash scripts/verify.sh`

---

## 5. Riferimenti

- [SYS-RECEPTION.md](../promises/system/SYS-RECEPTION.md)
- [SYS-CONTACTS.md](../promises/system/SYS-CONTACTS.md)
- [PROM-SHAREABLE-LINK.md](../promises/product/PROM-SHAREABLE-LINK.md)
- [PROM-CHAT-PEER-KEY.md](../promises/product/PROM-CHAT-PEER-KEY.md)
- [SURF-ALLOWLIST.md](./SURF-ALLOWLIST.md)
- [registry.md](../registry.md)
