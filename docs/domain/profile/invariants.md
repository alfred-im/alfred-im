# Invarianti — profile

**Bounded context:** `profile`  
**Implementazione:** `client/lib/machines/profile/`, `ProfileService`  
**Confine prodotto:** [SYS-PROFILE](../../specs/promises/system/SYS-PROFILE.md), [PROM-PROFILE-IDENTITY](../../specs/promises/product/PROM-PROFILE-IDENTITY.md)

---

1. Questo contesto modella **solo** il profilo dell'account autenticato (`UpdateOwnProfile`) — scheda peer è surfaccia delegata ([peer-profile](../peer-profile/)).
2. Identità pubblica = `username` + `ProfileSummary` — email non esposta in rubrica/ricerca.
3. Avatar/cover: bucket `avatars`, path `{userId}/…`, max 2 MB ([SYS-PROFILE](../../specs/promises/system/SYS-PROFILE.md)).
4. `ProfileSummary` è il modello unico per liste UI (inbox, sidebar, chat header) — niente DTO paralleli.
