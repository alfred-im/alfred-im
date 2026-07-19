# PROM-GROUP-AUTHOR-DISPLAY — Autore contenuto in chat gruppo

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `PROM-GROUP-AUTHOR-DISPLAY` |
| **Classe** | PRODUCT |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-19 |
| **PR origine** | #162 |

Promessa di prodotto: in contesto gruppo il testo è attribuito a `original_author_id` con intestazione avatar + nome; preview inbox indica l'autore umano quando presente.

Pipeline erogazione server: [SYS-GROUP](../system/SYS-GROUP.md) e [contracts/rpc.md](../../contracts/rpc.md).

---

## 1. Problema / obiettivo

In una chat con gruppo come peer, l'utente distingue **chi ha scritto** il contenuto (`original_author_id`) dal **contesto conversazione** (`peer_profile_id` = gruppo). Il mittente tecnico (`author_id` = gruppo su messaggi erogati) non sostituisce l'autore visibile.

---

## 2. Promesse

### MUST — rendering messaggio

| ID | Promessa |
|----|----------|
| **PROM-GROUP-AUTHOR-DISPLAY-001** | Campo canonico «chi ha scritto» in UI gruppo = autore originale del contenuto (`original_author_id`) |
| **PROM-GROUP-AUTHOR-DISPLAY-002** | Messaggi in arrivo in contesto gruppo: intestazione sopra la bolla con **avatar** (foto o iniziale colorata) e **nome leggibile** (`display_name`, fallback username senza `@`) |
| **PROM-GROUP-AUTHOR-DISPLAY-003** | Contesto conversazione resta con **gruppo** come `peer_profile_id` — non confondere autore contenuto con peer chat |
| **PROM-GROUP-AUTHOR-DISPLAY-004** | Messaggi in arrivo in chat gruppo: intestazione autore (avatar + nome) sopra la bolla |

### SHOULD — inbox e realtime

| ID | Promessa |
|----|----------|
| **PROM-GROUP-AUTHOR-DISPLAY-010** | Preview inbox per messaggio erogato: prefisso o formato che indica autore umano se `original_author_id` valorizzato |
| **PROM-GROUP-AUTHOR-DISPLAY-011** | Realtime: subscribe `messages` `owner_id = io` — account user riceve INSERT erogati; account group riceve INSERT in entrata — vedi [PROM-REALTIME-OWNER](./PROM-REALTIME-OWNER.md) |

### MUST NOT

| ID | Promessa |
|----|----------|
| **PROM-GROUP-AUTHOR-DISPLAY-020** | Mostrare `author_id` (mittente tecnico gruppo) come nome autore contenuto su messaggi erogati |
| **PROM-GROUP-AUTHOR-DISPLAY-021** | Nascondere intestazione autore su messaggi in arrivo in chat gruppo |

---


## 3. Modello (riferimento)

| Elemento | Artefatto |
|----------|-----------|
| Glossario / comandi | [docs/domain/groups/](../../../domain/groups/), [docs/domain/messaging/](../../../domain/messaging/) |
| UML | [docs/model/uml/groups/groups-state.puml](../../model/uml/groups/groups-state.puml) |
| Statechart client | [client/lib/machines/groups/](../../../client/lib/machines/groups/) |

**Implementazione (non vincolante):** [docs/domain/groups/README.md](../../../domain/groups/README.md) · [docs/guides/groups.md](../../../guides/groups.md)


## 4. Superfici conformi

| Superficie | Stato | File |
|------------|-------|------|
| Chat gruppo (user) | `implemented` | `chat_panel.dart`, `message_author_header.dart` |
| Chat gruppo (account group) | `implemented` | `group_conversation_screen.dart` |
| SURF-INBOX | `implemented` | [SURF-INBOX.md](../../surfaces/SURF-INBOX.md) — preview erogati |

---

## 5. Tracciabilità

| PROM-ID | Verifica |
|---------|----------|
| PROM-GROUP-AUTHOR-DISPLAY-001–004 | `group_message_display_test.dart`, `message_bubble_test.dart` |
| PROM-GROUP-AUTHOR-DISPLAY-010 | `inbox_controller.dart` — preview con autore |
| PROM-GROUP-AUTHOR-DISPLAY-011 | `group_delivery_smoke.sql`; Realtime owner filter tests |


Gate: `bash scripts/check-spec-sync.sh` + `cd client && bash scripts/verify.sh`

---

## 6. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [registry.md](../../registry.md) | Indice promesse |
| [SYS-GROUP](../system/SYS-GROUP.md) | Pipeline erogazione |
| [PROM-PROFILE-IDENTITY](./PROM-PROFILE-IDENTITY.md) | Avatar e nome |
| [PROM-GROUP-TICKS](./PROM-GROUP-TICKS.md) | Spunte separate per contesto gruppo |
