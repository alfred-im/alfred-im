# Contesto: shareable-link

**Stato modellazione:** `verified`

## Mapping dominio → implementazione

### Comandi ed eventi

| Dominio | Statechart | Codice |
|---------|------------|--------|
| `ResolveSharedLink` | `ResolveSharedLink` | `ShareableLinkAdapters.onFragmentChanged` |
| `HandleSharedLinkTarget` | `HandleSharedLinkTarget` | `ShareableLinkAdapters.onHandleRequested` |
| `OpenSharedChat` | effetto `openSharedChat` | → `NavigationAdapters.openFromShareableLink` |
| `OpenSharedProfile` | effetto `showProfileOverlay` | → `showPeerProfileOverlay` (`ViewPeerProfile`) |
| `DismissSharedLinkNotFound` | `DismissSharedLinkNotFound` | `ShareableLinkAdapters.onDismissNotFound` |

### Stati (UML ↔ `ShareableLinkState`)

| UML / evento | `ShareableLinkState` |
|--------------|----------------------|
| `Idle` | `idle` |
| `Pending` / `SharedLinkPending` | `pending` |
| `Resolving` | `resolving` |
| `Invalid` / `SharedLinkInvalid` | `invalid` |

Statechart: `client/lib/machines/shareable-link/` · Facade: `ShareableLinkController`

### Outcome impliciti (by design)

`SharedChatOpened`, `SharedProfileShown`, `SharedLinkPending` sono modellati come **stati** `ShareableLinkState`, non classi evento Dart — pattern coerente con altri contesti `verified`.

`OpenSharedProfile` chiama `showPeerProfileOverlay` direttamente (surfaccia peer-profile), non `ProfileMachine`.

`SharePeerProfile` (da overlay peer) è utility outbound (`shareShareableProfileLink`) — side-effect UI, non comando `ShareableLinkMachine`.
