# PROM-OVERLAY-DISMISS — Chiusura overlay fullscreen

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `PROM-OVERLAY-DISMISS` |
| **Classe** | PRODUCT |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-19 |
| **PR origine** | #163 |

Promessa di prodotto riusabile: chiudere overlay fullscreen (modale) con pulsante ✕ e tap sul barrier — pattern unificato, non callback sparse nel parent.

---

## 1. Problema / obiettivo

L'utente chiude overlay fullscreen (es. scheda profilo peer) in modo prevedibile e coerente. La logica di dismiss resta nel widget overlay, non propagata con callback ad hoc nei parent.

Prima implementazione: [PROM-PEER-PROFILE](./PROM-PEER-PROFILE.md). Estendibile ad altri overlay fullscreen conformi.

---

## 2. Promesse

### MUST — trigger chiusura

| ID | Promessa |
|----|----------|
| **PROM-OVERLAY-DISMISS-001** | Pulsante ✕ in overlay → chiusura |
| **PROM-OVERLAY-DISMISS-002** | Tap su barrier (area scura esterna al contenuto) → chiusura overlay |
| **PROM-OVERLAY-DISMISS-003** | Implementazione nel widget overlay conforme — **un solo** punto di dismiss documentato |

### SHOULD

| ID | Promessa |
|----|----------|
| **PROM-OVERLAY-DISMISS-010** | Transizione simmetrica all'apertura (fade/slide in chiusura) |

### MUST NOT

| ID | Promessa |
|----|----------|
| **PROM-OVERLAY-DISMISS-020** | Callback sparse nel parent (es. `HomeScreen`) per chiudere overlay su ogni azione navigazione |
| **PROM-OVERLAY-DISMISS-021** | Duplicare logica dismiss fuori dal widget overlay conforme |
| **PROM-OVERLAY-DISMISS-022** | Dialog di conferma prima della chiusura (dismiss ≠ annullare azione Allow/rubrica) |

### Fuori scope (follow-up)

- Tasto Indietro Android / Escape web per chiudere
- Navigazione programmatica che chiude overlay senza gesto utente

---


## 3. Modello (riferimento)

Pattern UI trasversale — nessun bounded context dedicato. Prima implementazione: [PROM-PEER-PROFILE](./PROM-PEER-PROFILE.md) · UML overlay: [seq-peer-profile-overlay.puml](../../model/uml/profile/seq-peer-profile-overlay.puml).

**Implementazione (non vincolante):** tracciabilità §6; binding [SURF-PEER-PROFILE](../../surfaces/SURF-PEER-PROFILE.md).


## 4. Superfici conformi

| Superficie | Stato | File |
|------------|-------|------|
| Overlay profilo peer | `implemented` | `peer_profile_overlay.dart`, [SURF-PEER-PROFILE](../../surfaces/SURF-PEER-PROFILE.md) |
| SURF-INBOX | `implemented` | tap avatar → overlay conforme |
| SURF-CONTACTS | `implemented` | tap avatar internal → overlay conforme |
| SURF-ALLOWLIST | `implemented` | tap entry → overlay conforme |

---

## 5. Tracciabilità

| PROM-ID | Verifica |
|---------|----------|
| PROM-OVERLAY-DISMISS-001–002 | `peer_profile_overlay.dart` — `barrierDismissible: true`; pulsante ✕ in `_ProfileHero` (verifica manuale / smoke UI) |
| PROM-OVERLAY-DISMISS-003 | `peer_profile_overlay.dart` — dismiss centralizzato; nessun callback parent |
| PROM-OVERLAY-DISMISS-020–021 | `peer_profile_overlay.dart` — nessun callback dismiss nel parent |


Gate: `bash scripts/check-spec-sync.sh` + `cd client && bash scripts/verify.sh`

---

## 6. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [registry.md](../../registry.md) | Indice promesse |
| [PROM-PEER-PROFILE](./PROM-PEER-PROFILE.md) | Overlay profilo peer |
| [SURF-PEER-PROFILE](../../surfaces/SURF-PEER-PROFILE.md) | Binding superficie |
| [PROM-LIST-FILTER](./PROM-LIST-FILTER.md) | Pattern dismiss unificato (lista) |
