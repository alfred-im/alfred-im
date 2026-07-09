# Scheda profilo peer in overlay

**Promesse**: [PROM-PEER-PROFILE.md](../specs/promises/product/PROM-PEER-PROFILE.md), [SURF-PEER-PROFILE.md](../specs/surfaces/SURF-PEER-PROFILE.md) · **PR**: #163, #176 · **Stato**: `implemented`

Documento per AI — tap avatar di un account Alfred altrui → modale fullscreen con identità pubblica, toggle allow list, azione rubrica e CTA chat sticky in basso.

---

## Entry point

| Elemento | Path |
|----------|------|
| Apertura overlay | `showPeerProfileOverlay(context, profile)` — `client/lib/widgets/peer_profile_overlay.dart` |
| Widget modale | `PeerProfileOverlay` |
| Avatar tappabile | `ProfileAvatar(onTap: …)` — `client/lib/widgets/profile_identity.dart` |

Skip profilo proprio: `profile.id == auth.userId` → nessun overlay.

---

## Punti di attivazione

| UI | Comportamento |
|----|---------------|
| `InboxPeerTile` | Tap **solo avatar** → overlay; tap riga → chat |
| `ChatPanel` header | Tap avatar peer |
| `MessageAuthorHeader` | Tap riga autore (gruppo) — `ChatMessage.toAuthorProfileSummary()` |
| `AllowedPeopleScreen` | Tap avatar in lista |
| `ContactsScreen` | Tap avatar solo contatti **internal** (`linked_profile_id`) |

Contatti rubrica **esterni**: nessun overlay (nessun `profiles.id`).

---

## Azioni (immediatamente, senza dialog)

| Controllo | Backend | Controller |
|-----------|---------|------------|
| Switch «Consenti messaggi» | `reception_allowlist` | `ReceptionAllowlistController.addProfile` / `removeByProfileId` |
| «Aggiungi / Rimuovi dalla rubrica» | `contacts` | `ContactsController.addInternal` / `removeInternalByProfileId` |
| **«Inizia a chattare»** (sticky in basso) | — | `AuthController.openConversation(ChatPeer.fromProfile(...))` dopo `Navigator.pop` |

Allow e rubrica sono **indipendenti** (semantica invariata rispetto a [SYS-RECEPTION](../specs/promises/system/SYS-RECEPTION.md) e [SYS-CONTACTS](../specs/promises/system/SYS-CONTACTS.md)). La CTA chat è **fuori** dall'area scrollabile (Allow + rubrica).

---

## Test

| REQ | Verifica |
|-----|----------|
| Overlay UI + CTA | `client/test/widget/peer_profile_overlay_test.dart` — PROM-PEER-PROFILE-013/014; SURF-PEER-PROFILE-015/016 |
| Rubrica remove | `client/test/unit/contacts_controller_test.dart` |
| Allow remove | `client/test/unit/reception_allowlist_controller_test.dart` |

Gate: `cd client && bash scripts/verify.sh` (**144** test).
