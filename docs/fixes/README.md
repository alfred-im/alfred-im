# Bug Fixes (Riferimento Tecnico)

Fix documentati per il client Flutter Alpha.

| File | PR | Problema |
|------|-----|----------|
| [flutter-inbox-stability.md](./flutter-inbox-stability.md) | #113, #114, #140 (§3) | Inbox bloccata su auth race; provider; evoluzione bootstrap multi-sessione |
| [auth-bootstrap-gotrue-revoke.md](./auth-bootstrap-gotrue-revoke.md) | #141, #142 | Bootstrap `signOut` revoca refresh token; PKCE senza storage |
| [conversations-empty-diagnosis.md](./conversations-empty-diagnosis.md) | — | Chat vuota: RPC silenziosa; checklist diagnosi |
| [multi-account-chat-persistence-pr143.md](./multi-account-chat-persistence-pr143.md) | #143 | Logout locale, view per account, persistenza F5, test regressione |

Architettura e testing: `docs/architecture/alpha-full-stack.md` §5.
