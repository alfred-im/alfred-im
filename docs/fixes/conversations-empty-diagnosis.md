# Diagnosi: «non si legge nulla nelle conversazioni»

**Data**: 2026-06-29  
**Status**: 🟡 Fix client in PR #143 — **validazione UI utente ancora negativa**  
**Categoria**: Messaggistica / auth / multi-account

Documento per AI.

---

## Segnalazione utente

Chat/conversazioni senza contenuto leggibile. Richiesta: **solo diagnosi**, no fix non concordati.

---

## Cosa è stato verificato (senza modificare codice produzione messaggi)

| Layer | Esito |
|-------|--------|
| DB live `messages` tra test1/test2/test3 | Body presenti (`ciao!`, `prova!`, …), `marker_type` null |
| RPC `list_peer_messages` con JWT test1 valido | Array con messaggi e `body` non vuoto |
| RPC `list_inbox` | Anteprime corrette (`ciao!`, `a te!`) |
| RPC senza JWT / JWT invalido | `[]` **senza errore HTTP** — silenzioso |
| Alpha + localhost con test1 (browser agente) | Testo leggibile in inbox e bolle chat |
| Widget test `MessageBubble` | Testo renderizzato con tema `Inter` |

---

## Ipotesi confermata (inbox piena, chat vuota)

**Disallineamento cache inbox vs fetch chat live** dopo sessione GoTrue morta (refresh revocato — es. vecchio `signOut` globale, test curl, bootstrap pre-#142):

1. `InboxController.peers` resta in memoria con anteprime caricate quando la sessione era valida
2. Apertura chat → `list_peer_messages` con JWT assente → `200` + `[]` silenzioso
3. `ChatPanel` non mostrava errori

**Fix client**: `onSessionEnded` svuota inbox; `MessagesController` rileva sessione assente / mismatch con `list_inbox`; `ChatPanel` mostra errore + Riprova.

---

## Ipotesi meno probabile (sessione valida)

**Sessione non autenticata o refresh revocato** → RPC ritorna `[]` → UI mostra lista vuota **senza messaggio di errore** (`ChatPanel` non espone `MessagesController.error`).

Fattori che revocano sessione:

- Bug bootstrap `signOut()` post-login (main pre-#142)
- Logout API/test su stesso account
- Refresh token scaduto/revocato in `restore()`

**Meno probabile**: testo invisibile (font/colori) — non osservato nei test.

---

## Checklist manuale (utente)

1. DevTools → Network → filtrare `rpc`.
2. Aprire chat con storico noto.
3. Controllare `list_peer_messages`:
   - `200` + array con `body` → bug UI client
   - `200` + `[]` → auth/peer sbagliato
   - `401` → sessione morta
4. Confrontare con `list_inbox` nella stessa sessione.

Riportare: URL (Alpha/localhost), account, esito inbox vs chat, snippet risposta RPC.

---

## File rilevanti

- `client/lib/services/message_service.dart` — `fetchPeerMessages`
- `client/lib/widgets/chat_panel.dart` — non mostra errori load
- `supabase/migrations/20260627230000_messages_only_inbox.sql` — `list_peer_messages`

---

## Fix multi-account correlati (PR #143)

Oltre sessione morta / RPC silenziosa:

- **View globale su `setFocus`** → `activePeer` errato tra account (fix: `AccountViewState` per `userId`)
- **InboxController disposed** al cambio focus (fix: `ListenableProxyProvider` noop dispose)
- **Persistenza** → un solo account dopo F5 (fix: `saveAllAccounts` atomico da tutte le sessioni)

Dettaglio: `docs/fixes/multi-account-chat-persistence-pr143.md`.

---

## Riferimenti

- `docs/fixes/multi-account-chat-persistence-pr143.md`
- `docs/fixes/auth-bootstrap-gotrue-revoke.md`
- `docs/AGENT_DEBUG_ACCOUNTS.md`
