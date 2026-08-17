# SYS-OWNER — Account owner e amministrazione istanza

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `SYS-OWNER` |
| **Classe** | SYSTEM |
| **Status** | `approved` |
| **Ultima revisione** | 2026-08-16 |

Account `profile_kind = owner`: stesso comportamento messaging di `user`, con pannelli amministrativi in client. Assegnazione **solo manuale** (SQL su `profiles`).

---

## Promesse MUST

| ID | Promessa |
|----|----------|
| **SYS-OWNER-001** | Enum `profile_kind` include `owner` |
| **SYS-OWNER-002** | Owner non creabile via registrazione pubblica (`handle_new_user` ignora metadata `owner`) |
| **SYS-OWNER-003** | `profiles.disabled_at` — ban disattiva accesso e messaggistica |
| **SYS-OWNER-004** | RPC `assert_session_active()` — rifiuta sessione se `disabled_at` valorizzato |
| **SYS-OWNER-005** | RPC `ban_profile` / `unban_profile` — solo owner; non ban su self né su altri owner |
| **SYS-OWNER-006** | RPC `upsert_instance_config` — solo owner; **solo** le quattro chiavi `instance.display_name`, `instance.im_server_id`, `instance.branding`, `instance.legal` (schema = `InstanceSettings`) |
| **SYS-OWNER-007** | RPC `get_instance_stats()` — solo owner |
| **SYS-OWNER-008** | Profili disattivati nascosti da `search_profiles` / `find_profile_by_username` (eccetto viewer owner) |

---

## Client (SURFACE correlate)

- `SURF-INBOX` — icona config server + pannello statistiche (solo owner)
- `SURF-PEER-PROFILE` — sezione moderazione ban/unban (solo owner viewer)
- `SURF-INSTANCE-CONFIG` — schermata editing `instance_config`
