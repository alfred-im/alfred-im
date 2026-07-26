# Invarianti — auth

**Bounded context:** `auth`  
**Implementazione:** `client/lib/utils/auth_identity.dart`, `client/lib/utils/friendly_auth_error.dart`  
**Confine prodotto:** [SURF-AUTH](../../specs/surfaces/SURF-AUTH.md)

---

## Identità

1. Username pubblico: pattern e normalizzazione in `AuthIdentity` (unica fonte).
2. Email: solo auth/recupero — stesso modulo.

## Errori utente

3. Messaggi auth da `friendlyAuthError` — mai eccezioni grezze in overlay.
4. Fallimenti permanenti sessione (refresh invalido/scaduto): `isPermanentAuthFailure` — stesso testo di sessione scaduta messaggistica.
