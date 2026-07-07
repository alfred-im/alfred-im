# PEER-PROFILE — Scheda profilo peer in overlay

| Campo | Valore |
|-------|--------|
| **Spec ID** | `PEER-PROFILE` |
| **Layer** | capability |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-07 |
| **ADR** | — |
| **PR** | #163 |
| **Correlata** | [PROFILE](./PROFILE.spec.md), [CONTACTS](./CONTACTS.spec.md), [RECEPTION-ALLOWLIST](./RECEPTION-ALLOWLIST.spec.md), [AUTH-MULTI](./AUTH-MULTI.spec.md) |

Documento per AI — overlay fullscreen al tap avatar di un account Alfred altrui: identità pubblica, toggle allow list, azione rubrica.

---

## 1. Problema / obiettivo

In diversi punti della piattaforma l’utente vede l’avatar di un altro account Alfred. Al tap sull’avatar deve aprirsi una modale fullscreen elegante con identità pubblica e due azioni **distinte**: consentire la ricezione messaggi (allow list) e aggiungere/rimuovere dalla rubrica personale.

Nessun cambio schema/RPC: composizione di [RECEPTION-ALLOWLIST](./RECEPTION-ALLOWLIST.spec.md) e [CONTACTS](./CONTACTS.spec.md).

---

## 2. Requisiti

### MUST

| ID | Requisito |
|----|-----------|
| **PEER-PROFILE-REQ-001** | Tap avatar peer Alfred → overlay fullscreen (`showPeerProfileOverlay`) |
| **PEER-PROFILE-REQ-002** | Overlay mostra: avatar grande, `display_name`, `@username` se presente, pronomi se presenti |
| **PEER-PROFILE-REQ-003** | Switch **Allow** («Consenti messaggi») ↔ `reception_allowlist` del focus — semantica RECEPTION-ALLOWLIST invariata |
| **PEER-PROFILE-REQ-004** | Pulsante rubrica «Aggiungi alla rubrica» / «Rimuovi dalla rubrica» ↔ `contacts` internal — semantica CONTACTS invariata |
| **PEER-PROFILE-REQ-005** | Allow e rubrica **indipendenti** — stato UI separato |
| **PEER-PROFILE-REQ-006** | Allow e rubrica: azione **immediata**, **senza** dialog di conferma |
| **PEER-PROFILE-REQ-007** | Profilo proprio (`profile.id == auth.userId`): **non** aprire overlay peer |
| **PEER-PROFILE-REQ-008** | Punti attivazione: tile inbox (solo avatar), header chat, autore messaggio gruppo, lista «Persone consentite», rubrica (solo internal) |
| **PEER-PROFILE-REQ-009** | `ContactsController.contactForProfileId` + `removeInternalByProfileId` per rimozione rubrica da overlay |
| **PEER-PROFILE-REQ-010** | `ReceptionAllowlistController.removeByProfileId` per toggle Allow off da overlay |
| **PEER-PROFILE-REQ-011** | Controller legati all’account in **focus** — [AUTH-MULTI](./AUTH-MULTI.spec.md) |

### SHOULD

| ID | Requisito |
|----|-----------|
| **PEER-PROFILE-REQ-012** | Transizione fade + slide leggero all’apertura overlay |
| **PEER-PROFILE-REQ-013** | Chiusura: pulsante ✕ e tap su barrier |
| **PEER-PROFILE-REQ-014** | `ProfileAvatar` accetta `onTap` opzionale con feedback ripple circolare |

### MUST NOT

| ID | Requisito |
|----|-----------|
| **PEER-PROFILE-REQ-015** | Confondere Allow (ricezione) con rubrica (scorciatoia) |
| **PEER-PROFILE-REQ-016** | Dialog di conferma su toggle Allow o azione rubrica nell’overlay |
| **PEER-PROFILE-REQ-017** | Esporre email del peer |
| **PEER-PROFILE-REQ-018** | Nuove RPC o tabelle — solo PostgREST esistente |
| **PEER-PROFILE-REQ-019** | Overlay per contatti rubrica **esterni** (senza `linked_profile_id`) |

---

## 3. Fuori scope

- Edit profilo altrui (bio, avatar upload)
- Toggle allow list globale on/off (vietato da RECEPTION-ALLOWLIST)
- Profilo federato `user@server` non risolto a `profiles.id`
- Retro-consegna messaggi al toggle Allow

---

## 4. Contratto

### 4.1 Backend

Invariato — vedi [RECEPTION-ALLOWLIST](./RECEPTION-ALLOWLIST.spec.md) e [CONTACTS](./CONTACTS.spec.md).

### 4.2 Client

| Componente | Responsabilità |
|------------|----------------|
| `showPeerProfileOverlay` | Entry point; skip self; `showGeneralDialog` fullscreen |
| `PeerProfileOverlay` | UI identità + switch Allow + pulsante rubrica |
| `ProfileAvatar.onTap` | Tap avatar riusabile |
| `ContactsController` | `contactForProfileId`, `removeInternalByProfileId` |
| `ReceptionAllowlistController` | `removeByProfileId` |
| `ChatMessage.toAuthorProfileSummary` | Profilo parziale da messaggio gruppo |

### 4.3 UX

| Condizione | Comportamento atteso |
|------------|----------------------|
| Tap avatar inbox | Overlay; tap resto tile → apre chat |
| Switch Allow ON | `addProfile` immediato |
| Switch Allow OFF | `removeByProfileId` immediato |
| In rubrica | Pulsante «Rimuovi dalla rubrica» |
| Non in rubrica | Pulsante «Aggiungi alla rubrica» |
| Contatto esterno rubrica | Nessun overlay al tap avatar |

---

## 5. Tracciabilità (requisito → verifica)

| REQ-ID | Verifica |
|--------|----------|
| PEER-PROFILE-REQ-003, REQ-010 | `reception_allowlist_controller_test.dart` — `removeByProfileId` |
| PEER-PROFILE-REQ-004, REQ-009 | `contacts_controller_test.dart` — `contactForProfileId`, `removeInternalByProfileId` |
| PEER-PROFILE-REQ-007 | `peer_profile_overlay_test.dart` — skip self |
| PEER-PROFILE-REQ-002, REQ-006, REQ-014 | `peer_profile_overlay_test.dart` — widget smoke |
| PEER-PROFILE-REQ-011 | `main.dart` — proxy provider focus |

Gate: `bash scripts/check-spec-sync.sh` + `cd client && bash scripts/verify.sh`

---

## 6. Scenari di accettazione

```gherkin
Scenario: Tap avatar peer in inbox
  Given utente U in focus e peer P in inbox
  When U tap sull'avatar di P
  Then si apre overlay con nome e @username di P
  And switch Allow riflette presenza di P in reception_allowlist

Scenario: Toggle Allow senza conferma
  Given overlay aperto per P non in allow list
  When U attiva switch Allow
  Then P è aggiunto a reception_allowlist senza dialog

Scenario: Rubrica indipendente da Allow
  Given P in allow list ma non in rubrica
  When U tap «Aggiungi alla rubrica»
  Then P è in contacts senza modificare allow list

Scenario: Profilo proprio
  Given U tap sul proprio avatar in contesto peer
  Then overlay peer non si apre
```

---

## 7. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [PROFILE](./PROFILE.spec.md) | `ProfileSummary`, widget avatar |
| [RECEPTION-ALLOWLIST](./RECEPTION-ALLOWLIST.spec.md) | Semantica Allow |
| [CONTACTS](./CONTACTS.spec.md) | Semantica rubrica |

**Codice**: `client/lib/widgets/peer_profile_overlay.dart`, `client/lib/widgets/profile_identity.dart`, `client/lib/providers/contacts_controller.dart`, `client/lib/providers/reception_allowlist_controller.dart`
