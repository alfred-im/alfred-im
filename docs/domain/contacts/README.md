# Contesto: contacts

**Stato modellazione:** `verified`

## Mapping dominio → implementazione

| Dominio | Statechart | Codice |
|---------|------------|--------|
| `AddContact` | `AddInternalContact` / `AddExternalContact` | `ContactService` |
| `RemoveContact` | `RemoveInternalContact` | `ContactService` |
| `SearchPeople` | — (sheet UI, non [ContactsMachine]) | `ContactsCoordinator.searchProfiles` → RPC `search_profiles` |
| `StartChatFromContact` | — (non [ContactsMachine]) | `ComposeService.peerFromContact` → `NavigationMachine.OpenPeerOnFocusedAccount` |
| `ContactListReady` | `ContactsLoaded` | `ContactsMachine` |

Statechart: `client/lib/machines/contacts/` · `ContactsCoordinator`
