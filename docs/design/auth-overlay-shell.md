# Shell sempre visibile + overlay credenziali

> **Superseded by spec**: [PROM-MULTI-ACCOUNT.md](../specs/promises/product/PROM-MULTI-ACCOUNT.md), [SURF-AUTH.md](../specs/surfaces/SURF-AUTH.md) — UX overlay; per contratto usare le promesse.

**Stato**: 🟢 Vincolante (client Alpha)  
**Data**: 2026-06-29  
**ADR**: [multi-account-parallel-sessions.md](../decisions/multi-account-parallel-sessions.md)  
**PR**: #140

Documento per AI — specifica UX del gate credenziali dopo il refactor multi-account.

---

## Principio

L’utente **non entra in Alfred**: apre il client di messaggistica e vi **opera** con una o più identità Alfred. La shell (layout inbox/chat) esiste **sempre**; le credenziali sono uno **strato temporaneo** sopra, non un’altra applicazione.

---

## Layout

```
Stack
├── HomeScreen (sempre)
│   ├── AccountSidebar
│   ├── InboxPanel | NoAccountPlaceholder
│   └── ChatPanel | EmptyChatPlaceholder
└── AuthOverlay (condizionale)
    └── AuthScreen (card centrata)
```

---

## Quando appare l’overlay

| Condizione | Overlay | Chiudibile |
|------------|---------|------------|
| 0 account aperti (primo avvio o dopo chiusura ultimo) | Sì, automatico | **No** |
| ≥1 account aperti, utente preme «Aggiungi account» | Sì | **Sì** (Annulla / tap fuori — stesso effetto) |

Dopo login/registrazione riusciti: overlay si chiude; shell mostra l’account appena aperto (in focus).

---

## Contenuto overlay

- Sfondo: `Colors.black` al **45%** opacità (`AuthOverlay`)
- Card: `AuthScreen` — logo, email, password
- Toggle **Accedi ↔ Registrati** sempre disponibile (anche da «Aggiungi account»)
- Recupero password: dialog modale (invariato)
- Titoli:
  - Primo account: «Accedi ad Alfred» / «Crea account Alfred»
  - Aggiungi account: «Aggiungi account Alfred»

---

## Placeholder senza account

`NoAccountPlaceholder` nell’area inbox quando non c’è focus o account:

- Logo Alfred ridotto
- «Nessun account aperto»
- Testo: apri o crea un account per vedere le conversazioni

La **sidebar** resta visibile (desktop) o apribile (drawer mobile) con voce «Aggiungi account»; senza account attivo la card profilo mostra messaggio neutro.

---

## Sidebar account

| Azione | Comportamento |
|--------|---------------|
| Tap altro account in lista | `setFocus` — **istantaneo**, nessun loading auth |
| Aggiungi account | Apre overlay chiudibile |
| Chiudi account (icona su card profilo) | `removeAccount`; se ultimo → overlay obbligatorio |

**Terminologia UI**: «Chiudi account» (non «Esci da Alfred») — coerente con il modello «credenziale messaggistica», non «utente app».

---

## Cosa NON fare

- ❌ Schermata auth a tutto schermo che sostituisce `HomeScreen`
- ❌ Rotella globale che nasconde la shell durante switch account
- ❌ Overlay dismissibile con 0 account (l’utente deve aprire almeno un account)
- ❌ Login e registrazione su schermate/route separate

---

## Riferimenti

- `client/lib/screens/home_screen.dart` — `Stack` + `_mainContent()` + `ListenableBuilder` inbox
- `client/lib/widgets/auth_overlay.dart`
- `client/lib/widgets/no_account_placeholder.dart`
- `client/lib/screens/auth_screen.dart`
- `docs/fixes/multi-account-single-active-gotrue-pr152.md` — runtime connessione (invariato UX overlay)
