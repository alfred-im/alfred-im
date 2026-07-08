# SURF-{NAME} — {Titolo schermata}

| Campo | Valore |
|-------|--------|
| **Superficie ID** | `SURF-{NAME}` |
| **Status** | `draft` \| `approved` \| `implemented` \| `deprecated` \| `superseded` |
| **Ultima revisione** | YYYY-MM-DD |
| **Promesse** | [PROM-…](../promises/product/PROM-….md) |

Binding promesse PRODUCT/SYSTEM su una schermata o widget.

---

## 1. Superficie

| Elemento | Valore |
|----------|--------|
| Widget / schermata | `client/lib/…` |
| Controller | … |

---

## 2. Promesse SURFACE

### MUST

| ID | Promessa |
|----|----------|
| `SURF-{NAME}-001` | Conforme a [PROM-…](../promises/product/PROM-….md) |
| `SURF-{NAME}-002` | … |

### MUST NOT

| ID | Promessa |
|----|----------|
| `SURF-{NAME}-010` | … |

---

## 3. Tracciabilità

| SURF-ID / PROM-ID | Verifica |
|-------------------|----------|
| `SURF-{NAME}-001` | `client/test/…` |

---

## 4. Riferimenti

- [registry.md](../registry.md)

Aggiornare [registry.md](../registry.md) quando si crea o cambia stato questa superficie.
