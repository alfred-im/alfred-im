# {TITLE}

| Campo | Valore |
|-------|--------|
| **Spec ID** | `{ID}` |
| **Layer** | capability |
| **Status** | `draft` \| `approved` \| `implemented` \| `deprecated` \| `superseded` |
| **Ultima revisione** | YYYY-MM-DD |
| **ADR** | [link](../decisions/…) |
| **PR** | #… |
| **Supersedes** | doc storici (opzionale) |
| **Superseded by** | `{OTHER-ID}` (se applicabile) |

Documento per AI — contratto di capability. Non duplicare ADR; referenziarli.

---

## 1. Problema / obiettivo

Breve descrizione del bisogno e del perimetro.

---

## 2. Requisiti

### MUST (vincolanti)

- …

### SHOULD

- …

### MUST NOT

- …

---

## 3. Fuori scope

- …

---

## 4. Contratto

### 4.1 Backend / RPC

Vedi [contracts/rpc.md](../contracts/rpc.md) per firme condivise. Dettagli specifici:

| Elemento | Comportamento |
|----------|---------------|
| … | … |

### 4.2 Client

| Componente | Responsabilità |
|------------|----------------|
| … | … |

### 4.3 UX (se applicabile)

| Condizione | Comportamento atteso |
|------------|----------------------|
| … | … |

---

## 5. Verifica

| Tipo | Riferimento |
|------|-------------|
| Gate | `cd client && bash scripts/verify.sh` |
| Smoke DB | `supabase/tests/…` |
| Integrazione | `bash scripts/test.sh integration` |
| E2E | `bash scripts/test.sh e2e-multi` (se applicabile) |

---

## 6. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| … | … |

**Codice**: `client/lib/…`, `supabase/migrations/…`
