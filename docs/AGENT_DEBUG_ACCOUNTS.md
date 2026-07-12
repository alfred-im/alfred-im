# Account debug agente (Supabase live)

Documento operativo per sessioni Cursor Cloud / agenti AI. **Non** è documentazione utente.

> ⚠️ **2026-07-12 — account agente ELIMINATI.** Su richiesta dell'utente, `alfredagent1` e
> `alfredagent2` sono stati rimossi **completamente** dal Supabase live: `auth.users`, `profiles`,
> tutti i messaggi/conversazioni (incluse le copie recapitate ad altri account) e le voci
> `reception_allowlist`. **Non esistono più** e i vecchi UUID non vanno riusati. Se servono account
> di debug, **crearne di nuovi dedicati** (mai usare/toccare `test1`…`test4`, che sono dell'utente).
> Le credenziali storiche qui sotto sono conservate solo come traccia storica.

## Regola obbligatoria

| Azione | Consentito |
|--------|------------|
| Usare account `alfredagent1` / `alfredagent2` per debug auth, multi-account, messaggistica | ✅ Sì |
| Modificare password, email, profilo di `test1`, `test2`, `test3` o altri account dell'utente | ❌ **Mai** |
| Eseguire `UPDATE auth.users` su account non elencati in questa pagina | ❌ **Mai** (salvo istruzione esplicita dell'utente) |

Gli account `test1` / `test2` / `test3` appartengono all'utente. Per test integrazione usare **solo** gli account agente sotto.

---

## Incidente 2026-06-29 (da non ripetere)

Durante il debug del bug «Aggiungi account → sessione scaduta», un agente ha eseguito su Supabase live:

```sql
UPDATE auth.users SET encrypted_password = crypt('AlfredDebug1!', ...)
WHERE email = 'agadriel.sexpositive+1@gmail.com';
-- idem test2 con AlfredDebug2!
```

**Effetto:** password di `test1` e `test2` sovrascritte senza autorizzazione. Le password originali **non sono recuperabili** (solo hash in DB).

**Recupero per l'utente:** recupero password dall'app o dashboard Supabase → Authentication → Users.

**Lezione:** per debug auth creare o usare account dedicati agente; non toccare account esistenti.

---

## Incidente 2026-07-09 — signup fake su live (bounce email)

Durante debug redirect conferma email, un agente ha eseguito `signUp` su Supabase **live** con indirizzi inventati (`redirect-probe-*@gmail.com`). Le caselle non esistono → bounce → avviso deliverability Supabase.

**Regola:** ❌ **Mai** `signUp` su live con email inventate (`probe@`, `test@` finti, domini inesistenti).

**Alternativa corretta:**
- Account agente già confermati (`alfredagent1` / `alfredagent2`) — vedi sopra
- Test flusso signup: indirizzo **reale** con plus (`agadriel.sexpositive+…@gmail.com`) oppure conferma via SQL senza inviare mail
- Test redirect API: `GET /auth/v1/verify` con token da DB, **senza** triggerare `mail.send`

Account probe rimossi da Auth il 2026-07-09.

---

## Account agente (creati 2026-06-29 — ELIMINATI 2026-07-12)

> ❌ **Non più attivi.** Account e dati rimossi dal live il 2026-07-12 (vedi banner in cima).
> Tabella conservata solo come riferimento storico; le credenziali non sono più valide.

Progetto Supabase: `tvwpoxxcqwphryvuyqzu` (stesso della demo live).

| Username | Email | Password | UUID |
|----------|-------|----------|------|
| `alfredagent1` | `agadriel.sexpositive+alfredagent1@gmail.com` | `AlfredAgentDbg1!` | `efd885fe-b36e-48fc-a796-0e3f153e40d6` |
| `alfredagent2` | `agadriel.sexpositive+alfredagent2@gmail.com` | `AlfredAgentDbg2!` | `0a81f785-173c-4f1c-b5df-3937086a2482` |

- Email confermate via SQL (`email_confirmed_at`) per login immediato.
- Profili creati dal trigger `handle_new_user`.
- Destinati a: login, add-account, messaggi tra agent1 ↔ agent2, test integrazione.

### Verifica rapida (curl)

```bash
curl -sS -X POST "$SUPABASE_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email":"agadriel.sexpositive+alfredagent1@gmail.com","password":"AlfredAgentDbg1!"}'
```

### Recupero password dall'app

Il client bootstrap usa `EphemeralPkceStorage` (`pkceAsyncStorage`) con `EmptyLocalStorage` —
non PKCE senza storage (crash null) né `AuthFlowType.implicit`. Vedi PR #142 e
`docs/guides/multi-account.md`.

---

## Account utente (non modificare)

Presenti nel DB live; **non** usare per esperimenti che cambiano credenziali o dati.

| Username | Email (nota) |
|----------|----------------|
| `test1` | `agadriel.sexpositive+1@gmail.com` |
| `test2` | `agadriel.sexpositive+2@gmail.com` |
| `test3` | `agadriel.sexpositive+3@gmail.com` |
| `test4` | `agadriel.sexpositive+4@gmail.com` |

---

**Ultimo aggiornamento:** 2026-07-09 (incidente bounce probe; credenziali invariate)
