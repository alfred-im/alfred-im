# Invarianti — multi-account

**Bounded context:** `multi-account`  
**Implementazione:** [SessionAuthority](session-authority.md) (`client/lib/services/session_authority.dart`, `part of account_manager.dart`)  
**Verifica sessione:** `AccountManager.isSessionReadyForAccount` + `SessionAuthority.ensureFocusReady`  
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

Regole in [navigation/invariants.md § Account session](../navigation/invariants.md#account-session-senza-peer).

## Enforcement

Tutti gli invarianti di questa pagina passano da [SessionAuthority](session-authority.md). Vietato: switch identità, `restore`, `dispose` sessione o sync push auth **fuori** da SessionAuthority.
