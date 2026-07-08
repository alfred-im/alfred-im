# PROM-GROUP-AUTHOR-DISPLAY — Autore contenuto in chat gruppo

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `PROM-GROUP-AUTHOR-DISPLAY` |
| **Classe** | PRODUCT |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-08 |
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
| **PROM-GROUP-AUTHOR-DISPLAY-001** | Campo canonico «chi ha scritto» in UI gruppo = `original_author_id` (`ChatMessage.contentAuthorId`) |
| **PROM-GROUP-AUTHOR-DISPLAY-002** | Messaggi in arrivo in contesto gruppo: intestazione sopra la bolla con **avatar** (foto o iniziale colorata) e **nome leggibile** (`display_name`, fallback username senza `@`) |
| **PROM-GROUP-AUTHOR-DISPLAY-003** | Contesto conversazione resta con **gruppo** come `peer_profile_id` — non confondere autore contenuto con peer chat |
| **PROM-GROUP-AUTHOR-DISPLAY-004** | Arricchimento autori via `enrichMessageAuthor` + `MessageAuthorHeader` quando `peerIsGroup` |

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

## 4. Contratto implementativo

| Elemento | Responsabilità |
|----------|----------------|
| `ChatMessage.contentAuthorId` | `original_author_id` — chi ha scritto |
| `author_display.dart` | `enrichMessageAuthor` — nome + avatar da `ProfileSummary` |
| `MessageAuthorHeader` | Widget avatar + nome sopra bolla (messaggi in arrivo) |
| `GroupConversationScreen` | Lista messaggi archivio gruppo |
| `MessagesController` / `GroupMessagesController` | Arricchimento quando `peerIsGroup` |
| Tap avatar autore | [PROM-PEER-PROFILE](./PROM-PEER-PROFILE.md) |

### Semantica autori (riferimento)

| Situazione | `author_id` | `original_author_id` | UI mostra |
|------------|-------------|----------------------|-----------|
| Erogazione verso persona | gruppo | umano | **umano** |
| Gruppo broadcast su membro | gruppo | gruppo | **gruppo** |
| Umano → gruppo (storico gruppo) | umano | umano | **umano** |
| Chat private user↔user | umano | NULL | controparte |

---

## 5. Superfici conformi

| Superficie | Stato | File |
|------------|-------|------|
| Chat gruppo (user) | `implemented` | `chat_panel.dart`, `message_author_header.dart` |
| Chat gruppo (account group) | `implemented` | `group_conversation_screen.dart` |
| SURF-INBOX | `implemented` | [SURF-INBOX.md](../../surfaces/SURF-INBOX.md) — preview erogati |

---

## 6. Tracciabilità

| PROM-ID | Verifica |
|---------|----------|
| PROM-GROUP-AUTHOR-DISPLAY-001–004 | `group_message_display_test.dart`, `message_bubble_test.dart` |
| PROM-GROUP-AUTHOR-DISPLAY-010 | `inbox_controller.dart` — preview con autore |
| PROM-GROUP-AUTHOR-DISPLAY-011 | `group_delivery_smoke.sql`; Realtime owner filter tests |


Gate: `bash scripts/check-spec-sync.sh` + `cd client && bash scripts/verify.sh`

---

## 7. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [registry.md](../../registry.md) | Indice promesse |
| [SYS-GROUP](../system/SYS-GROUP.md) | Pipeline erogazione |
| [PROM-PROFILE-IDENTITY](./PROM-PROFILE-IDENTITY.md) | Avatar e nome |
| [PROM-GROUP-TICKS](./PROM-GROUP-TICKS.md) | Spunte separate per contesto gruppo |
