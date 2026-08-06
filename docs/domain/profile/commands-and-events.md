# Comandi ed eventi — contesto profile

**Ultima revisione:** 2026-07-27  
**UML:** [docs/model/uml/profile/](../../model/uml/profile/)

Comandi della **scheda peer** (surfaccia delegata): [peer-profile/commands](../peer-profile/README.md#comandi-ed-eventi-surfaccia).

---

## Comandi

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `UpdateOwnProfile` | Utente | Salva nome, bio, pronomi, avatar, copertina. |

---

## Eventi

| Evento | Descrizione |
|--------|-------------|
| `OwnProfileUpdated` | Identità propria salvata. |

---

## Policy

| Policy | Descrizione |
|--------|-------------|
| **Username immutabile** | Identità pubblica username non editabile dal profilo. |
