# SURF-PROFILE — Schermata profilo utente

| Campo | Valore |
|-------|--------|
| **Superficie ID** | `SURF-PROFILE` |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-08 |
| **Promesse** | [SYS-PROFILE](../promises/system/SYS-PROFILE.md) |
| **PR** | #118, #134 |

Binding UX modifica profilo proprio: form edit, avatar, campi read-only identità stabile.

---

## 1. Superficie

| Elemento | Valore |
|----------|--------|
| Schermata | `client/lib/screens/profile_screen.dart` |
| Controller | `ProfileController` — stato save/upload |
| Servizi | `ProfileService`, `ProfileAvatarService` |
| Widget condivisi | `ProfileAvatar`, `ProfileIdentityLines` (`profile_identity.dart`) |
| Modello | `ProfileSummary`, `UserProfile` |

---

## 2. Promesse SURFACE

### MUST

| ID | Promessa |
|----|----------|
| **SURF-PROFILE-001** | Email GoTrue: solo lettura in UI profilo; usata per login/recupero |
| **SURF-PROFILE-002** | Username: `@username` read-only sotto avatar — non modificabile da schermata profilo Alpha |
| **SURF-PROFILE-003** | Campi editabili: `display_name` (obbligatorio), `bio`, `pronouns`, foto avatar |
| **SURF-PROFILE-004** | Modello UI unificato `ProfileSummary`: `id`, `displayName`, `username?`, `avatarUrl?`, `pronouns?` |
| **SURF-PROFILE-005** | Widget condivisi: `ProfileAvatar` (foto o iniziale colorata), `ProfileIdentityLines` (nome, `@username`, pronomi) |
| **SURF-PROFILE-006** | Dopo salvataggio: `AuthController.refreshProfile()` → aggiorna manifest account (`OpenAccount.profile`) |
| **SURF-PROFILE-007** | Foto: tap camera → file picker → upload bucket `avatars` + save profilo |

### SHOULD

| ID | Promessa |
|----|----------|
| **SURF-PROFILE-008** | Stringhe opzionali (`bio`, `pronouns`) salvate come `null` se vuote dopo trim |
| **SURF-PROFILE-009** | Fallback avatar: `CircleAvatar` con iniziale da `display_name` e colore deterministico per `id` |
| **SURF-PROFILE-010** | Pronomi: hint con esempi; bio multilinea |

### MUST NOT

| ID | Promessa |
|----|----------|
| **SURF-PROFILE-015** | Modificare `username` da schermata profilo Alpha |

---

## 4. Tracciabilità

| SURF-ID | Verifica |
|-----------------------|----------|
| SURF-PROFILE-001 | `profile_screen.dart` — email disabilitata |
| SURF-PROFILE-002 | `profile_screen.dart` — username read-only |
| SURF-PROFILE-003 | `profile_service.dart` — `.from('profiles').update()` |
| SURF-PROFILE-004 | `models_and_utils_test.dart` — `ProfileSummary.fromProfilesRow` |
| SURF-PROFILE-005 | `models_and_utils_test.dart` — `avatarColorForId`; `widgets/profile_identity.dart` |
| SURF-PROFILE-006 | `account_storage_test.dart` — `OpenAccount.profile` round-trip; `auth_controller.dart` `refreshProfile` |
| SURF-PROFILE-007 | `profile_avatar_service.dart`; `profile_screen.dart` picker |
| SURF-PROFILE-008 | `models_and_utils_test.dart` — `UserProfile.fromJson` |

Gate: `cd client && bash scripts/verify.sh`

---

## 5. Riferimenti

- [SYS-PROFILE.md](../promises/system/SYS-PROFILE.md)
- [SURF-ACCOUNT-SIDEBAR.md](./SURF-ACCOUNT-SIDEBAR.md) — manifest `OpenAccount.profile`
- [registry.md](../registry.md)
