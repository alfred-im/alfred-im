# Comandi ed eventi — contesto profile

**Ultima revisione:** 2026-09-13  
**UML:** [docs/model/uml/profile/](../../model/uml/profile/)  
**Amend:** `get_profiles` — distillazione TEMP §7

Comandi della **scheda peer** (surfaccia delegata): [peer-profile/commands](../peer-profile/README.md#comandi-ed-eventi-surfaccia).

---

## Comandi

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `UpdateOwnProfile` | Utente | Salva nome, bio, pronomi, avatar, copertina. |
| `FetchProfiles` | Policy (UI) | Batch `get_profiles(addresses[])` per presentazione peer. |

---

## Eventi

| Evento | Descrizione |
|--------|-------------|
| `OwnProfileUpdated` | Identità propria salvata. |
| `ProfilesFetched` | Batch `get_profiles` completato — presentazione aggiornata. |

---

## Policy

| Policy | Descrizione |
|--------|-------------|
| **Username immutabile** | Identità pubblica username non editabile dal profilo. |
| **Profilo pubblico sempre** | `get_profiles` non gated da allow list del richiedente. |
| **Nessun profilo shadow** | Peer remoto: risposta RPC/federata, non INSERT in `profiles`. |
| **Fallback indirizzo** | Se lookup fallisce: UI mostra indirizzo grezzo. |
