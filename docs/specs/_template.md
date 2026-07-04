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

Ogni requisito vincolante ha un **REQ-ID** stabile: `{SPEC-ID}-REQ-NNN` (es. `MAILBOX-SEND-REQ-001`).

### MUST

| ID | Requisito |
|----|-----------|
| `{ID}-REQ-001` | … |

### SHOULD

| ID | Requisito |
|----|-----------|
| `{ID}-REQ-0xx` | … |

### MUST NOT

| ID | Requisito |
|----|-----------|
| `{ID}-REQ-0xx` | … |

---

## 3. Fuori scope

- …

---

## 4. Contratto

### 4.1 Backend

Vedi [contracts/schema.md](../contracts/schema.md) e [contracts/rpc.md](../contracts/rpc.md).

### 4.2 Client

| Componente | Responsabilità |
|------------|----------------|
| … | … |

### 4.3 UX (se applicabile)

| Condizione | Comportamento atteso |
|------------|----------------------|
| … | … |

---

## 5. Tracciabilità (requisito → verifica)

| REQ-ID | Verifica |
|--------|----------|
| `{ID}-REQ-001` | `client/test/…` o `supabase/tests/…` |

Aggiornare questa tabella quando si aggiungono test dedicati a un requisito.

---

## 6. Scenari di accettazione (opzionale)

```gherkin
Scenario: …
  Given …
  When …
  Then …
```

---

## 7. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| … | … |

**Codice**: `client/lib/…`, `supabase/migrations/…`
