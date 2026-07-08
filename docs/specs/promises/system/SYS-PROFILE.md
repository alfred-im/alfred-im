# SYS-PROFILE — Profilo utente (piattaforma)

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `SYS-PROFILE` |
| **Classe** | SYSTEM |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-08 |
| **Contratti** | [schema.md](../../contracts/schema.md) · [rpc.md](../../contracts/rpc.md) |
| **PR** | #118, #134 |

Promesse di piattaforma per tabella `profiles`, bucket avatar, RLS e RPC di esposizione identità pubblica.

---

## 1. Problema / obiettivo

Ogni utente Alfred ha un profilo pubblico legato 1:1 a `auth.users`. Il backend garantisce schema, vincoli, storage avatar e campi profilo peer esposti da RPC inbox e ricerca — senza email in superfici pubbliche.

---

## 2. Promesse SYSTEM

### MUST

| ID | Promessa |
|----|----------|
| **SYS-PROFILE-001** | Tabella `profiles`: `id` (= `auth.uid()`), `username`, `display_name`, `bio`, `avatar_url`, `pronouns`, `created_at`, `updated_at` |
| **SYS-PROFILE-002** | `username`: formato `^[a-z0-9_]{3,32}$`, univoco case-insensitive; impostato in registrazione — non modificabile via UPDATE client Alpha |
| **SYS-PROFILE-003** | Modifica profilo proprio: UPDATE diretto su `profiles` via RLS `profiles_update_own` (`id = auth.uid()`) |
| **SYS-PROFILE-004** | Campi editabili Alpha: `display_name` (obbligatorio), `bio`, `pronouns`, `avatar_url` |
| **SYS-PROFILE-005** | Avatar: bucket `avatars`, path `{userId}/avatar.{jpg\|png\|webp}`, max **2 MB**, URL pubblico; upsert sullo stesso path |
| **SYS-PROFILE-006** | RPC `list_inbox()` espone `peer_avatar_url`, `peer_pronouns` per ogni riga peer |
| **SYS-PROFILE-007** | RPC `find_profile_by_username` ritorna `id`, `username`, `display_name`, `avatar_url`, `pronouns` |

### SHOULD

| ID | Promessa |
|----|----------|
| **SYS-PROFILE-008** | Stringhe opzionali (`bio`, `pronouns`) persistite come `null` se vuote dopo trim |

### MUST NOT

| ID | Promessa |
|----|----------|
| **SYS-PROFILE-015** | Esporre email in `search_profiles`, `list_inbox` o altre RPC/query profilo pubblico |
| **SYS-PROFILE-017** | Avatar fuori dalla cartella `auth.uid()` in bucket `avatars` |

---

## 3. Contratto

| Elemento | Comportamento |
|----------|---------------|
| `profiles` | RLS: SELECT authenticated; UPDATE solo propria riga |
| `profiles.pronouns` | Testo libero opzionale |
| Bucket `avatars` | Pubblico; MIME jpeg/png/webp; 2 MB; RLS cartella = `auth.uid()` |
| `list_inbox()` | Join `profiles` → `peer_avatar_url`, `peer_pronouns` |
| `find_profile_by_username` | Risoluzione username → profilo pubblico |

Migrazioni: `20260624200000_alfred_domain_schema.sql`, `20260628000000_profile_pronouns_avatars.sql`, `20260628100000_inbox_peer_profile_fields.sql`.

Nessuna RPC dedicata `update_profile` — client usa PostgREST `.from('profiles').update()`.

---

## 5. Tracciabilità

| SYS-ID | Verifica |
|----------------------|----------|
| SYS-PROFILE-001 | `schema_smoke.sql` — tabella `profiles`; `20260624200000_alfred_domain_schema.sql` |
| SYS-PROFILE-002 | `profile_screen.dart` — username read-only; registrazione `auth_screen.dart` |
| SYS-PROFILE-003 | `profile_service.dart` — `.from('profiles').update()`; RLS migrazioni domain |
| SYS-PROFILE-005 | `20260628000000_profile_pronouns_avatars.sql`; `profile_avatar_service.dart` |
| SYS-PROFILE-006 | `20260628100000_inbox_peer_profile_fields.sql`; [SYS-MAILBOX](./SYS-MAILBOX.md) SYS-MAILBOX-003 |
| SYS-PROFILE-007 | `schema_smoke.sql` — `find_profile_by_username` |
| SYS-PROFILE-008 | `models_and_utils_test.dart` — `UserProfile.fromJson` |
| SYS-PROFILE-015 | [SYS-CONTACTS](./SYS-CONTACTS.md); RPC `search_profiles` / `list_inbox` — nessun campo email |

Gate: `bash scripts/check-spec-sync.sh` · `cd client && bash scripts/verify.sh`

---

## 6. Riferimenti

- [registry.md](../../registry.md)
- [SURF-PROFILE.md](../../surfaces/SURF-PROFILE.md) — schermata profilo
- [contracts/schema.md](../../contracts/schema.md) · [contracts/rpc.md](../../contracts/rpc.md)
