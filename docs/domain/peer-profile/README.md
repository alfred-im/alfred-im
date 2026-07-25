# Surfaccia: peer-profile

**Stato modellazione:** `documented` (overlay UI — **non** è un bounded context separato)

## Confine

La **scheda profilo peer** è una surfaccia modale (`showPeerProfileOverlay`) che mostra identità pubblica e azioni contestuali su un account Alfred altrui. I comandi di dominio sono **delegati** ai contesti sottostanti — nessuna logica duplicata in `profile`.

- Identità **propria**: contesto [profile](../profile/)
- Guida implementativa: [guides/peer-profile.md](../../guides/peer-profile.md)
- UML: [seq-peer-profile-overlay.puml](../../model/uml/profile/seq-peer-profile-overlay.puml)

## Mapping dominio → implementazione

| Dominio | Statechart | Delega a | Codice |
|---------|------------|----------|--------|
| `ViewPeerProfile` | `OpenPeerProfile` | — | overlay peer, `ProfileMachine` |
| `TogglePeerConsent` | `ToggleAllowMessages` | `ReceptionMachine` | `reception_allowlist` |
| `TogglePeerInContacts` | `ToggleRubrica` | `ContactsMachine` | `ContactService` |
| `StartChatFromPeerProfile` | `StartChatFromProfile` | `NavigationMachine` | `openConversation` |
| `SharePeerProfile` | `ShareProfileLink` | shareable-link | `shareShareableProfileLink` |

Statechart: `client/lib/machines/profile/` · `ProfileCoordinator` (comandi peer nell'overlay)
