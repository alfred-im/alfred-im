# Scheda profilo peer

**Contratto**: [PROM-PEER-PROFILE](../specs/promises/product/PROM-PEER-PROFILE.md), [SURF-PEER-PROFILE](../specs/surfaces/SURF-PEER-PROFILE.md), [PROM-SHAREABLE-LINK](../specs/promises/product/PROM-SHAREABLE-LINK.md)

Tap avatar di un account Alfred altrui → modale fullscreen con identità, allow list, rubrica, CTA chat.

---

## Entry point

| Elemento | Path |
|----------|------|
| Apertura | `showPeerProfileOverlay` — `peer_profile_overlay.dart` |
| Avatar tappabile | `ProfileAvatar(onTap: …)` |

Skip profilo proprio: `profile.id == auth.userId`.

---

## Attivazione

| UI | Comportamento |
|----|---------------|
| `InboxPeerTile` | Tap avatar → overlay; tap riga → chat |
| `ChatPanel` header | Tap avatar |
| `MessageAuthorHeader` | Tap autore (gruppo) |
| `AllowedPeopleScreen` / `ContactsScreen` | Tap avatar (solo internal per rubrica) |

---

## Azioni

| Controllo | Backend |
|-----------|---------|
| «Consenti messaggi» | `reception_allowlist` |
| Rubrica | `contacts` |
| **Condividi** | `shareShareableProfileLink` → URL `#indirizzo` |
| **«Inizia a chattare»** | `openConversation` dopo chiusura overlay |

Allow e rubrica sono indipendenti.

---

## Test

`peer_profile_overlay_test.dart`, `shareable_link_test.dart`
