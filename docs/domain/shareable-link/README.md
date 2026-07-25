# Contesto: shareable-link

**Stato modellazione:** `verified`

## Artefatti

| Livello | File |
|---------|------|
| Dominio | [glossary.md](./glossary.md), [commands-and-events.md](./commands-and-events.md) |
| UML | [shareable-link-state.puml](../../model/uml/shareable-link/shareable-link-state.puml), [seq-open-from-fragment.puml](../../model/uml/shareable-link/seq-open-from-fragment.puml) |
| Statechart | [client/lib/machines/shareable-link/](../../../client/lib/machines/shareable-link/) |

## Mapping dominio → implementazione

| Dominio | Statechart | Codice |
|---------|------------|--------|
| `ResolveSharedLink` | `ParseFragment`, `HandleTargetRequested` | `ShareableLinkMachine` |
| `OpenSharedChat` | `OpenFromShareableLink` | → `NavigationMachine` |
| `OpenSharedProfile` | `ShowProfileFromLink` | overlay profilo |
| `SharedLinkPending` | `TargetDeferred` | coda fino a sessione |
| `SharedLinkInvalid` | `ProfileNotFound` | UI not found |

Statechart: `client/lib/machines/shareable-link/` · `ShareableLinkController`
