# SURF-GROUP-SHELL — Shell account gruppo

| Campo | Valore |
|-------|--------|
| **Superficie ID** | `SURF-GROUP-SHELL` |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-08 |
| **Promesse** | [SYS-RECEPTION](../promises/system/SYS-RECEPTION.md), [SYS-GROUP](../promises/system/SYS-GROUP.md) |
| **PR** | #162; amend home → — |

Binding UX shell dedicata quando focus su account `profile_kind = group`: home stile inbox ([SURF-GROUP-HOME](./SURF-GROUP-HOME.md)) + conversazione su navigazione esplicita.

---

## 1. Superficie

| Elemento | Valore |
|----------|--------|
| Router | `client/lib/screens/home_screen.dart` — branch `profile_kind == group` |
| Home gruppo | `client/lib/widgets/group_home_panel.dart` — [SURF-GROUP-HOME](./SURF-GROUP-HOME.md) |
| Schermata chat | `client/lib/screens/group_conversation_screen.dart` — [SURF-GROUP-CONVERSATION](./SURF-GROUP-CONVERSATION.md) |
| Riuso | `AllowedPeopleScreen`, `ProfileScreen` |
| Registrazione | `client/lib/screens/auth_screen.dart` — toggle tipo account |

---

## 2. Promesse SURFACE

### MUST

| ID | Promessa |
|----|----------|
| **SURF-GROUP-SHELL-001** | Dopo login account gruppo: compare nel manifest multi-account come ogni altro account |
| **SURF-GROUP-SHELL-002** | Account gruppo in focus: schermata **default** = [SURF-GROUP-HOME](./SURF-GROUP-HOME.md) (non conversazione diretta) |
| **SURF-GROUP-SHELL-003** | Entry profilo e allow list **propria** nella home gruppo (header); non più barra profilo/allow list sopra la chat |
| **SURF-GROUP-SHELL-004** | Account `user`: inbox e chat invariati; peer gruppo = `peer_profile_id` del profilo gruppo |
| **SURF-GROUP-SHELL-005** | Profilo gruppo: stessi campi e UI di [SURF-PROFILE](./SURF-PROFILE.md) (`display_name`, `bio`, `avatar_url`, `pronouns`; username non editabile) |
| **SURF-GROUP-SHELL-006** | Client registrazione: stessa schermata auth utente con opzione tipo account (`user` / `group`) |

### SHOULD

| ID | Promessa |
|----|----------|
| **SURF-GROUP-SHELL-007** | Etichetta UI distinta per account `group` nel manifest (badge «Gruppo») — vedi anche [SURF-ACCOUNT-SIDEBAR](./SURF-ACCOUNT-SIDEBAR.md) |
| **SURF-GROUP-SHELL-008** | Vista storico gruppo: messaggi ordinati per `created_at` su archivio `owner_id = gruppo` |

### MUST NOT

| ID | Promessa |
|----|----------|
| **SURF-GROUP-SHELL-010** | ~~Inbox a lista conversazioni~~ → **Sostituito**: home con **una** riga conversazione ([SURF-GROUP-HOME-007](./SURF-GROUP-HOME.md)); vietata lista multipla peer |
| **SURF-GROUP-SHELL-011** | Aprire conversazione gruppo come unica schermata al focus senza passare dalla home |

### Deprecato (superseded da amend)

| ID | Era | Ora |
|----|-----|-----|
| SURF-GROUP-SHELL-002 (PR #162) | Solo vista conversazione + entry profilo/allow list | Default = home; chat su tap riga |
| SURF-GROUP-SHELL-003 (PR #162) | Allow list sopra conversazione | Profilo/allow list in header home |
| SURF-GROUP-SHELL-010 (PR #162) | No inbox | Home stile inbox con una voce |

---

## 4. Tracciabilità

| SURF-ID | Verifica |
|---------------------|----------|
| SURF-GROUP-SHELL-002 | `group_home_panel_test.dart`, `home_screen_group_test.dart` |
| SURF-GROUP-SHELL-003 | `group_home_panel_test.dart` — header entry |
| SURF-GROUP-SHELL-006 | `AuthScreen` — toggle tipo account |
| SURF-GROUP-SHELL-007 | `account_sidebar_test.dart` |
| SURF-GROUP-SHELL-001 | `account_manager_persistence_test.dart` (`profileKind` manifest) |
| SURF-GROUP-SHELL-011 | `home_screen_group_test.dart` — default non è chat |

Gate: `check-spec-sync.sh` + `verify.sh` + smoke SQL gruppo

---

## 5. Riferimenti

- [SURF-GROUP-HOME.md](./SURF-GROUP-HOME.md)
- [SURF-GROUP-CONVERSATION.md](./SURF-GROUP-CONVERSATION.md)
- [SURF-ACCOUNT-SIDEBAR.md](./SURF-ACCOUNT-SIDEBAR.md)
- [registry.md](../registry.md)
