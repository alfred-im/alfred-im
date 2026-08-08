# Invarianti — shareable-link

**Bounded context:** `shareable-link`  
**Implementazione:** `client/lib/machines/shareable-link/`, fragment URL `#`  
**Confine prodotto:** [PROM-SHAREABLE-LINK](../../specs/promises/product/PROM-SHAREABLE-LINK.md)

---

1. Formati stabili: `#username` (profilo) e `#username/chat` (apertura chat) — parsing centralizzato in adapter.
2. Risoluzione username → `profile_id` via RPC; peer irrisolvibile → stato `invalid`, nessuna chat commessa.
3. `OpenSharedChat` delega a `NavigationAdapters.openFromShareableLink` — shareable-link non possiede scope messaggistica.
4. `OpenSharedProfile` → overlay peer (`ViewPeerProfile`) — non schermata profilo proprio.
5. Intent fragment consumato una volta; dismiss not-found non lascia scope attivo.
