# Surfaccia: peer-profile

**Stato modellazione:** `documented` (overlay UI — **non** è un bounded context separato)

## Confine

La **scheda profilo peer** è una surfaccia modale (`showPeerProfileOverlay`) che mostra identità pubblica e azioni contestuali su un account Alfred altrui. I comandi di dominio sono **delegati** ai contesti sottostanti — nessuna logica in `ProfileMachine` / `ProfileCoordinator` (riservati all'edit profilo proprio).

- Identità **propria**: contesto [profile](../profile/)
- Guida implementativa: [guides/peer-profile.md](../../guides/peer-profile.md)
- UML: [seq-peer-profile-overlay.puml](../../model/uml/profile/seq-peer-profile-overlay.puml)

## Comandi ed eventi (surfaccia)

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `ViewPeerProfile` | Utente | Mostra identità del peer. |
| `TogglePeerConsent` | Utente | Consente o revoca recapito messaggi dal peer. |
| `TogglePeerInContacts` | Utente | Aggiunge o rimuove peer dalla rubrica. |
| `StartChatFromPeerProfile` | Utente | Apre conversazione dalla scheda peer. |
| `SharePeerProfile` | Utente | Condivide link al profilo peer. |

| Evento | Descrizione |
|--------|-------------|
| `PeerProfileDisplayed` | Scheda peer visibile con dati completi. |
| `PeerConsentChanged` | Consenso recapito aggiornato (delega `reception`). |
| `PeerContactListChanged` | Presenza in rubrica aggiornata (delega `contacts`). |

### Policy

| Policy | Descrizione |
|--------|-------------|
| **Nessuna scheda su sé stessi** | Tap sul proprio avatar non apre overlay peer. |
| **Allow e rubrica indipendenti** | Toggle immediati, senza dialog di conferma. |

## Mapping dominio → implementazione

| Dominio (surfaccia) | Statechart delegato | Delega a | Codice |
|---------------------|---------------------|----------|--------|
| `ViewPeerProfile` | — | — | `showPeerProfileOverlay`, `peer_profile_overlay.dart` |
| `TogglePeerConsent` | `AddAllowedProfile` / `RemoveAllowedPerson` | `ReceptionMachine` | `ReceptionAllowlistController` |
| `TogglePeerInContacts` | `AddInternalContact` / `RemoveInternalContact` | `ContactsMachine` | `ContactsController` |
| `StartChatFromPeerProfile` | `OpenPeerOnFocusedAccount` | `NavigationMachine` | `AuthController.openConversation` |
| `SharePeerProfile` | — | shareable-link utility | `shareShareableProfileLink` |

Overlay: `client/lib/widgets/peer_profile_overlay.dart`
