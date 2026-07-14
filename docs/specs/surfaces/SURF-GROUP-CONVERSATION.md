# SURF-GROUP-CONVERSATION — Vista conversazione gruppo

| Campo | Valore |
|-------|--------|
| **Superficie ID** | `SURF-GROUP-CONVERSATION` |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-08 |
| **Promesse** | — |
| **PR** | #162 |

Binding UX messaggistica gruppo: attribuzione autore contenuto, header avatar+nome, storico gruppo, preview inbox erogati.

---

## 1. Superficie

| Elemento | Valore |
|----------|--------|
| Schermata | `client/lib/screens/group_conversation_screen.dart` |
| Controller | `GroupMessagesController` / `MessagesController` — `enrichMessageAuthor` quando `peerIsGroup` |
| Widget | `MessageAuthorHeader`, `MessageBubble` |
| Utilità | `client/lib/utils/author_display.dart` — `enrichMessageAuthor` |
| Modello | `ChatMessage.contentAuthorId` = `original_author_id` |

---

## 2. Promesse SURFACE

### MUST

| ID | Promessa |
|----|----------|
| **SURF-GROUP-CONVERSATION-001** | UI messaggio in contesto gruppo: testo attribuito **sempre** a `original_author_id` (campo canonico «chi ha scritto») |
| **SURF-GROUP-CONVERSATION-002** | Intestazione sopra la bolla con **avatar** (foto o iniziale colorata) e **nome leggibile** (`display_name`, fallback username senza `@`) |
| **SURF-GROUP-CONVERSATION-003** | Contesto conversazione con **gruppo** (`peer_profile_id`) per messaggi erogati su archivio `user` |
| **SURF-GROUP-CONVERSATION-004** | Account `group`: storico via query su `messages` WHERE `owner_id = auth.uid()` ORDER BY `created_at` (non `list_inbox`) |
| **SURF-GROUP-CONVERSATION-005** | Account `user`: `list_inbox()` e `list_peer_messages(gruppo)` includono messaggi erogati con `peer_profile_id = gruppo` |
| **SURF-GROUP-CONVERSATION-006** | Gruppo in focus: compose broadcast (`sendGif` / `sendVoice` / `sendLocation` / `sendImage` / `sendVideo`) verso allow list — [PROM-CHAT-MEDIA](../promises/product/PROM-CHAT-MEDIA.md) |
| **SURF-GROUP-CONVERSATION-009** | Apertura da [SURF-GROUP-HOME](./SURF-GROUP-HOME.md): non è schermata default al focus gruppo |
| **SURF-GROUP-CONVERSATION-012** | Header chat allineato a [SURF-CHAT](./SURF-CHAT.md) `ChatPanel`: back su mobile, avatar + nome gruppo, bordo inferiore — **senza** entry allow list né sottotitolo «Account gruppo» |

### SHOULD

| ID | Promessa |
|----|----------|
| **SURF-GROUP-CONVERSATION-007** | Realtime: subscribe `messages` `owner_id = io` — account user riceve INSERT erogati; account group riceve INSERT in entrata |
| **SURF-GROUP-CONVERSATION-008** | Preview inbox per messaggio erogato: prefisso o formato che indica autore umano se `original_author_id` valorizzato |

### MUST NOT

| ID | Promessa |
|----|----------|
| **SURF-GROUP-CONVERSATION-010** | Esporre al mittente umano quali partecipanti hanno ricevuto l'erogazione |
| **SURF-GROUP-CONVERSATION-011** | `author_id = umano` su righe erogate verso partecipanti in UI (mittente tecnico = gruppo) |

---

## 4. Tracciabilità

| SURF-ID | Verifica |
|---------------------|----------|
| SURF-GROUP-CONVERSATION-001–003 | `group_message_display_test.dart`, `message_bubble_test.dart` |
| SURF-GROUP-CONVERSATION-004 | `group_conversation_screen_test.dart` |
| SURF-GROUP-CONVERSATION-005 | `mailbox_inbox_smoke.sql`; integration |
| SURF-GROUP-CONVERSATION-006 | `group_messages_controller_media_test.dart`, `group_broadcast_smoke.sql` |
| SURF-GROUP-CONVERSATION-009, 012 | `group_conversation_screen_test.dart`; `home_screen_group_test.dart` |
| SURF-GROUP-CONVERSATION-007 | realtime subscribe `messages` owner filter |

Gate: `check-spec-sync.sh` + `verify.sh` + smoke SQL + `integration`

---

## 5. Riferimenti

- [SURF-GROUP-HOME.md](./SURF-GROUP-HOME.md)
- [SURF-GROUP-SHELL.md](./SURF-GROUP-SHELL.md)
- [SYS-GROUP](../promises/system/SYS-GROUP.md)
- [registry.md](../registry.md)
