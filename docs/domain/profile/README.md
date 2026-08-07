# Contesto: profile

**Stato modellazione:** `verified`

Identità **propria** dell'account autenticato (`UpdateOwnProfile`). Per la scheda peer (overlay su altri utenti) vedi [peer-profile](../peer-profile/) — surfaccia delegata, non parte di questo contesto.

## Mapping dominio → implementazione

| Dominio | Statechart | Codice |
|---------|------------|--------|
| `UpdateOwnProfile` | `SaveProfile`, `UploadAvatar`, `UploadCover` | `ProfileService`, `ProfileAvatarService` |

Statechart: `client/lib/machines/profile/` · `ProfileCoordinator` (solo edit profilo proprio)
