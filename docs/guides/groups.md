# Account gruppo — client

**Contratto**: [SYS-GROUP](../specs/promises/system/SYS-GROUP.md), [SYS-DELIVERY](../specs/promises/system/SYS-DELIVERY.md)

---

## Modello

- **Gruppo** = account con `profile_kind = group` (`ProfileKind`, `ProfileSummary.isGroup`)
- **Partecipazione** = allow list bidirezionale (`reception_allowlist`)
- **Focus su gruppo** → nessuna inbox; una sola conversazione (storico unico)

---

## Shell

| File | Ruolo |
|------|--------|
| `home_screen.dart` | Branch gruppo → `_GroupAccountLayout` (no `InboxPanel`) |
| `group_home_panel.dart` | Home gruppo |
| `group_conversation_screen.dart` | Storico + broadcast |
| `group_messages_controller.dart` | `fetchOwnerMessages`, broadcast, realtime su `owner_id` |

Mobile (<720px): `GroupHomePanel` → chat full-width dopo `openGroupChat()`.

---

## Chat umano → gruppo

`MessagesController` con `peerIsGroup`; etichette autore (`MessageAuthorHeader`, `author_display.dart`).  
`list_inbox` espone `peer_profile_kind`.

---

## Delivery

Invio umano→gruppo: copia mittente + outbox → worker INSERT storico gruppo + `alfred_delivery.erogate_group_message`.  
Broadcast: una riga archivio gruppo + outbox `group_erogate`.  
Spunte umano→gruppo: ✓✓ = recapito al gruppo.

Smoke: `group_delivery_smoke.sql`, `group_broadcast_smoke.sql`
