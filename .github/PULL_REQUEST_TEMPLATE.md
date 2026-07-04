## Descrizione

<!-- Cosa cambia e perché -->

## Spec-Driven Development

- [ ] **Nessun cambio di contratto** (bug fix / refactor interno)
- [ ] **Contratto aggiornato**: spec in `docs/specs/capabilities/` o `docs/specs/contracts/`
  - Spec ID: <!-- es. MAILBOX-SEND -->
  - Stato spec: `draft` | `approved` | `implemented`
  - REQ-ID toccati: <!-- es. MAILBOX-SEND-REQ-003, oppure N/A -->

## Verifica

- [ ] `cd client && bash scripts/verify.sh`
- [ ] `bash scripts/check-spec-sync.sh` (se toccate `docs/specs/` o `supabase/migrations/`)

## Registro

- [ ] `CHANGELOG.md` / `alpha-pr-registry.md` aggiornati se merge su `main`
