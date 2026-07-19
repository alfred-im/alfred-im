# Comandi ed eventi — contesto shareable-link

**Ultima revisione:** 2026-07-19  
**UML:** [docs/model/uml/shareable-link/](../../model/uml/shareable-link/)

---

## Comandi (intento)

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `ParseFragment` | Policy (hashchange / bootstrap) | Normalizza fragment URL; aggiorna target o torna idle. |
| `HandleTargetRequested` | Policy | Tenta risoluzione se sessione pronta e target in coda. |
| `SessionBecameReady` | Policy (auth pronta) | Sblocca consumo target in coda. |
| `OpenFromShareableLink` | Policy (target chat risolto) | Delega a navigation: focus + apertura chat. |
| `ShowProfileFromLink` | Policy (target profilo) | Mostra overlay identità peer. |
| `DismissNotFound` | Utente | Azzera stato not-found e fragment. |

---

## Eventi di dominio

| Evento | Dopo | Descrizione |
|--------|------|-------------|
| `FragmentParsed` | `ParseFragment` ok | Target in coda. |
| `FragmentCleared` | fragment assente o invalido | Torna idle. |
| `TargetDeferred` | sessione non pronta o zero account | Target conservato in coda. |
| `ProfileResolved` | lookup username ok | Profilo trovato. |
| `ProfileNotFound` | lookup fallito | Indirizzo non risolvibile — UI not found. |
| `SelfPeerIgnored` | peer == account in focus | Target scartato senza errore. |
| `ChatOpenedFromLink` | `OpenFromShareableLink` ok | Navigation ha aperto chat corretta. |
| `ProfileOverlayShown` | `ShowProfileFromLink` | Scheda profilo peer visibile. |

---

## Policy

| Policy | Trigger | Azione |
|--------|---------|--------|
| **Attendi sessione** | target + sessione non pronta | `TargetDeferred` |
| **No guest** | zero account aperti | Overlay auth; target resta in coda |
| **Clear stale chat** | `#peer/chat` con chat su altro peer | Navigation chiude chat stale |
| **Fallback profilo** | peer assente da inbox | Lookup profilo + apertura conversazione |

---

## Tracciabilità SDD

| Elemento modello | Promessa |
|------------------|----------|
| Formato fragment | PROM-SHAREABLE-LINK-001–007 |
| Multi-account / auth | PROM-SHAREABLE-LINK-010–012 |
| `#…/chat` senza stale | PROM-SHAREABLE-LINK-004, 024 |
| Not found | PROM-SHAREABLE-LINK-006 |
| Condivisione profilo | PROM-SHAREABLE-LINK-003 |
