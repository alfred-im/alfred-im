# Gruppi — client Flutter (PR #162)

Documento per AI — implementazione client per [SYS-GROUP](../specs/promises/system/SYS-GROUP.md).

---

## Modello

- **Gruppo** = account Alfred con `profile_kind = group` (`ProfileSummary.isGroup`, `ProfileKind` enum).
- **Partecipazione** = allow list bidirezionale (`reception_allowlist`) — stessa UI «Persone consentite» degli account umani.
- **Nessuna inbox** quando il focus è su un account gruppo: una sola conversazione (storico unico).

---

## Registrazione e manifest

| File | Ruolo |
|------|--------|
| `lib/screens/auth_screen.dart` | Toggle «Account personale» / «Account gruppo» in signup |
| `lib/providers/auth_controller.dart` | Passa `profile_kind` in `user_metadata` |
| `lib/models/profile_summary.dart` | `ProfileKind`, serializzazione in manifest (`profileKind` in JSON account) |
| `lib/widgets/account_sidebar.dart` | Badge «Gruppo» per account `group` nel manifest |

---

## Shell account gruppo

| File | Ruolo |
|------|--------|
| `lib/screens/home_screen.dart` | Branch: se focus `profileKind == group` → layout gruppo (no `InboxPanel`) |
| `lib/screens/group_conversation_screen.dart` | Storico unico + compose broadcast; header profilo + allow list |
| `lib/providers/group_messages_controller.dart` | `fetchOwnerMessages`, broadcast testo/media (`send`, `sendGif`, `sendVoice`, `sendLocation`), realtime su `owner_id` |

Layout mobile: sotto 720px la conversazione è full-width (drawer per sidebar account).

---

## Chat con peer gruppo (account umano)

| File | Ruolo |
|------|--------|
| `lib/screens/home_screen.dart` | `MessagesController` con `peerIsGroup: peer.isGroup` |
| `lib/providers/messages_controller.dart` | Arricchimento autori quando `peerIsGroup` |
| `lib/widgets/chat_panel.dart` | Prop `showAuthorLabels` |
| `lib/widgets/anchored_message_list.dart` | Passa `showAuthorLabel` a `MessageBubble` |

`list_inbox` espone `peer_profile_kind` per identificare peer gruppo senza fetch aggiuntivo.

---

## UI autore messaggio

Campo canonico: `ChatMessage.contentAuthorId` (= `original_author_id` dal backend).

| File | Ruolo |
|------|--------|
| `lib/utils/author_display.dart` | `authorLabelForProfile`, `enrichMessageAuthor` — nome leggibile + avatar |
| `lib/widgets/message_author_header.dart` | Avatar 12px + nome sopra la bolla |
| `lib/widgets/message_bubble.dart` | Header **fuori** dalla bolla; solo messaggi in arrivo (`!isMine`) |

Etichetta: `display_name` se presente, altrimenti username **senza** `@`. Messaggi propri: nessun header (come chat private).

---

## Backend client (servizi)

| RPC / metodo | Uso |
|--------------|-----|
| `list_owner_messages` | Storico account gruppo |
| `broadcast_message_to_allowlist` | Invio broadcast dal gruppo (testo, GIF, voice, location) |
| `MessageMediaService` | Upload media prima del broadcast |
| `send_message_to_profile` | Umano→gruppo o gruppo→persona (invariato lato client) |
| `ProfileService.fetchSummariesByIds` | Hydrate profili autori per etichette |

---

## Test

| Test | Copertura |
|------|-----------|
| `test/unit/group_shell_test.dart` | `ProfileKind` in manifest |
| `test/unit/group_message_display_test.dart` | `contentAuthorId`, `enrichMessageAuthor` |
| `test/widget/message_bubble_test.dart` | Header autore con nome leggibile |

Smoke SQL: `supabase/tests/group_schema_smoke.sql`, `group_delivery_smoke.sql`, `group_broadcast_smoke.sql`.

---

## Fuori scope v1 (documentato in spec)

- Preview inbox con prefisso autore umano (`SYS-GROUP-033` SHOULD)
- Membership / inviti / ruoli admin
- Federazione gruppi

---

**Riferimenti**: [SYS-GROUP.md](../specs/promises/system/SYS-GROUP.md), [contracts/rpc.md](../specs/contracts/rpc.md)
