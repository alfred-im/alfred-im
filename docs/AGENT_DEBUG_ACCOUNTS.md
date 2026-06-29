# Account debug agente (Supabase live)

Documento operativo per sessioni Cursor Cloud / agenti AI. **Non** è documentazione utente.

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

## Account agente (creati 2026-06-29)

Progetto Supabase: `tvwpoxxcqwphryvuyqzu` (stesso dell'app Alpha).

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

Il client bootstrap per `resetPasswordForEmail` deve usare `AuthFlowType.implicit`
(non PKCE senza storage) — vedi fix PR #142. Se compare «null value» o rate limit,
usare dashboard Supabase → Authentication → Users per reimpostare password account utente.

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

**Ultimo aggiornamento:** 2026-06-29
