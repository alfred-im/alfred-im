# PROM-BOTTOM-ANCHOR — Aggancio lista messaggi al fondo

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `PROM-BOTTOM-ANCHOR` |
| **Classe** | PRODUCT |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-08-08 |

Promessa di prodotto: la lista messaggi in conversazione resta **agganciata al fondo** mentre l'utente legge i messaggi recenti; scroll nello storico **stacca** l'aggancio; pulsante ↓ e badge per messaggi arrivati mentre staccato.

Distinto da paginazione storico verso l'alto — [SURF-CHAT-015](../../surfaces/SURF-CHAT.md) / `list_peer_messages`.

---

## 1. Problema / obiettivo

L'utente legge la conversazione senza che nuovi messaggi spostino la vista se sta consultando lo storico; torna al fondo con gesto esplicito o tap su ↓.

---

## 2. Promesse

### MUST

| ID | Promessa |
|----|----------|
| **PROM-BOTTOM-ANCHOR-001** | Apertura chat → vista sul fondo (agganciata) |
| **PROM-BOTTOM-ANCHOR-002** | Entro soglia dal fondo (`ConversationScrollAnchor`, default **48 px**) → nuovi messaggi auto-scroll al fondo |
| **PROM-BOTTOM-ANCHOR-003** | Scroll verso storico oltre soglia → **staccato**; messaggi in arrivo non spostano la vista |
| **PROM-BOTTOM-ANCHOR-004** | Messaggio inviato dall'utente → sempre scroll al fondo |
| **PROM-BOTTOM-ANCHOR-005** | Staccato: pulsante ↓ visibile; tap → scroll animato al fondo e riaggancio |
| **PROM-BOTTOM-ANCHOR-006** | Staccato: badge su ↓ = messaggi ricevuti mentre staccato (cap `99+`) |
| **PROM-BOTTOM-ANCHOR-007** | Stesso comportamento in chat 1:1 e gruppo (`AnchoredMessageList` condiviso) |

### MUST NOT

| ID | Promessa |
|----|----------|
| **PROM-BOTTOM-ANCHOR-020** | Auto-scroll forzato mentre l'utente legge storico (staccato) |

---

## 3. Modello (riferimento)

Pattern UI trasversale — nessun bounded context dedicato.

**Implementazione (non vincolante):** [guides/chat-scroll.md](../../../guides/chat-scroll.md) · `anchored_message_list.dart` · `conversation_scroll_anchor.dart`.

---

## 4. Superfici conformi

| Superficie | Stato | File |
|------------|-------|------|
| SURF-CHAT | `implemented` | [SURF-CHAT.md](../../surfaces/SURF-CHAT.md) — SURF-CHAT-019 |
| SURF-GROUP-CONVERSATION | `implemented` | [SURF-GROUP-CONVERSATION.md](../../surfaces/SURF-GROUP-CONVERSATION.md) — SURF-GROUP-CONVERSATION-015 |

---

## 5. Tracciabilità

| PROM-ID | Verifica |
|---------|----------|
| PROM-BOTTOM-ANCHOR-001–007 | `conversation_scroll_anchor_test.dart`; `anchored_message_list.dart` |

Gate: `bash scripts/check-spec-sync.sh` + `cd client && bash scripts/verify.sh`

---

## 6. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [registry.md](../../registry.md) | Indice promesse |
| [chat-scroll.md](../../../guides/chat-scroll.md) | Guida operativa |
