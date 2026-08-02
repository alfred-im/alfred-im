# Invarianti — multi-account

**Bounded context:** `multi-account`  
**Implementazione attuale:** `client/lib/services/account_manager.dart`, guard sparse  
**Implementazione target:** [SessionAuthority](session-authority.md) — unico enforcement identità  
**Verifica sessione:** `client/lib/utils/conversation_session_access.dart`  
**Confine prodotto:** [PROM-MULTI-ACCOUNT](../../specs/promises/product/PROM-MULTI-ACCOUNT.md)

---

## Sessione attiva

1. **Al massimo una** **Account session** GoTrue in RAM (vedi [glossary.md](glossary.md)).
2. Cambio focus: **dispose** sessione corrente + **restore** da manifest — mai due JWT attivi in parallelo.
3. Storage GoTrue dedicato per account (`alfred_auth_{userId}`).

## Manifest

4. Sidebar = voci nel manifest (account aperti), non bookmark esterni.
5. Account senza refresh token valido → stato disconnesso (non rimozione silenziosa dal manifest).

## Account session ready

Regole in [navigation/invariants.md § Account session](../navigation/invariants.md#account-session-senza-peer) — oggi `AccountManager.isSessionReadyForAccount`; target `SessionAuthority.isOwnerReady`.

## Enforcement

Tutti gli invarianti di questa pagina devono passare da [SessionAuthority](session-authority.md). Vietato: `executeFocus`, `restore`, `dispose` sessione o sync push auth **fuori** da SessionAuthority (salvo migrazione esplicita documentata in session-authority § Migrazione).
