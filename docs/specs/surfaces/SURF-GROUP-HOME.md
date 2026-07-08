# SURF-GROUP-HOME — Home account gruppo

| Campo | Valore |
|-------|--------|
| **Superficie ID** | `SURF-GROUP-HOME` |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-08 |
| **Promesse** | [SYS-GROUP](../promises/system/SYS-GROUP.md), [SYS-PROFILE](../promises/system/SYS-PROFILE.md), [PROM-PROFILE-IDENTITY](../promises/product/PROM-PROFILE-IDENTITY.md), [PROM-GROUP-AUTHOR-DISPLAY](../promises/product/PROM-GROUP-AUTHOR-DISPLAY.md) |
| **PR** | — |

Binding UX home account `profile_kind = group`: riepilogo, persone più attive, unica riga conversazione (stile inbox) — graficamente uniforme a [SURF-INBOX](./SURF-INBOX.md), senza ricerca né FAB.

---

## 1. Superficie

| Elemento | Valore |
|----------|--------|
| Widget | `client/lib/widgets/group_home_panel.dart` (nuovo) |
| Controller | `GroupHomeController` (nuovo) — aggregazione su storico `list_owner_messages` |
| Parent | `client/lib/screens/home_screen.dart` — branch `profileKind == group` |
| Riuso visivo | Guscio `InboxPanel` (`AlfredColors.panel`, header, divider); `InboxPeerTile` per riga conversazione; `ProfileAvatar` |
| Navigazione chat | Tap riga conversazione → [SURF-GROUP-CONVERSATION](./SURF-GROUP-CONVERSATION.md) |

---

## 2. Promesse SURFACE

### MUST

| ID | Promessa |
|----|----------|
| **SURF-GROUP-HOME-001** | Account gruppo in focus: schermata **default** = home gruppo (non conversazione) — vedi [SURF-GROUP-SHELL](./SURF-GROUP-SHELL.md) |
| **SURF-GROUP-HOME-002** | Guscio visivo **uniforme** a `InboxPanel`: stesso pannello (`AlfredColors.panel`), header con drawer su mobile, divider, tipografia e spaziatura lista |
| **SURF-GROUP-HOME-003** | Header home: titolo = **nome del gruppo** (`display_name`); entry profilo proprio e entry allow list **propria** (icone come inbox user per allow list) |
| **SURF-GROUP-HOME-004** | Blocco riepilogo: data **nascita** gruppo da `profiles.created_at` (profilo completo account in focus); conteggio **totale messaggi** nello storico `owner_id = gruppo` |
| **SURF-GROUP-HOME-005** | Sezione **«Persone più attive»**: elenco autori che hanno scritto almeno un messaggio nello storico del gruppo, ordinati per **conteggio messaggi decrescente**; ogni riga: avatar, nome leggibile, numero messaggi |
| **SURF-GROUP-HOME-006** | Autore per aggregazione: `original_author_id` (UI: `ChatMessage.contentAuthorId`); escludere messaggi il cui autore contenuto è l’id del **gruppo** stesso (broadcast tecnici) |
| **SURF-GROUP-HOME-007** | **Una** riga conversazione in fondo all’area lista, stile `InboxPeerTile`: titolo = **nome del gruppo**; anteprima ultimo messaggio e etichetta tempo come inbox user ([SURF-CHAT](./SURF-CHAT.md) SURF-CHAT-008 per tipi media) |
| **SURF-GROUP-HOME-008** | Tap sulla riga conversazione = **unico** ingresso alla chat gruppo (`GroupConversationScreen`); nessun FAB né pulsante separato |
| **SURF-GROUP-HOME-009** | Layout **desktop** largo: home nel pannello centrale; chat a destra quando riga selezionata — stesso split di inbox user + chat |
| **SURF-GROUP-HOME-010** | Layout **mobile**: home default; tap riga → chat full-width con back → home |

### SHOULD

| ID | Promessa |
|----|----------|
| **SURF-GROUP-HOME-011** | Idratazione nomi/avatar autori «persone più attive» via `ProfileService.fetchSummariesByIds` (stesso pattern di `GroupMessagesController`) |
| **SURF-GROUP-HOME-012** | Riga conversazione evidenziata (`selected`) quando chat gruppo aperta su desktop |

### MUST NOT

| ID | Promessa |
|----|----------|
| **SURF-GROUP-HOME-020** | Campo ricerca / lente filtro in home gruppo |
| **SURF-GROUP-HOME-021** | FAB «nuovo messaggio» o altro FAB in home gruppo |
| **SURF-GROUP-HOME-022** | Mostrare **partecipanti effettivi**, membership bidirezionale, o qualunque dato derivato dalle **allow list di altri account** |
| **SURF-GROUP-HOME-023** | Usare la allow list del gruppo come fonte per «persone più attive» — solo storico messaggi propri |
| **SURF-GROUP-HOME-024** | Lista di più conversazioni peer in home gruppo — **una** sola riga archivio |

---

## 3. Fonti dati (lecite)

| UI | Fonte |
|----|--------|
| Nome, avatar, nascita | Profilo proprio (`profiles` account gruppo) |
| Totale messaggi, ultimo messaggio, tile anteprima | `list_owner_messages` / archivio `owner_id = gruppo` |
| Persone più attive | Aggregazione client su `original_author_id` nello stesso archivio |
| Allow list | Solo navigazione alla **propria** schermata allow list — non statistiche membership |

---

## 4. Tracciabilità

| SURF-ID | Verifica |
|---------|----------|
| SURF-GROUP-HOME-001, 009, 010 | `home_screen_group_test.dart` |
| SURF-GROUP-HOME-002, 007, 008 | `group_home_panel_test.dart` |
| SURF-GROUP-HOME-004 | fetch profilo + conteggio messaggi |
| SURF-GROUP-HOME-005, 006, 011 | `group_home_controller_test.dart` |
| SURF-GROUP-HOME-020, 021, 022 | assenza widget ricerca/FAB; no RPC allow list altrui |

Gate: `check-spec-sync.sh` + `verify.sh`

---

## 5. Riferimenti

- [SURF-GROUP-SHELL.md](./SURF-GROUP-SHELL.md)
- [SURF-GROUP-CONVERSATION.md](./SURF-GROUP-CONVERSATION.md)
- [SURF-INBOX.md](./SURF-INBOX.md)
- [registry.md](../registry.md)
