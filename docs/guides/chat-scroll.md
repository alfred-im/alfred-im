# Aggancio al fondo conversazione

**Backlog SDD**: `PROM-BOTTOM-ANCHOR` in [registry.md](../specs/registry.md) — non ancora promessa PRODUCT.

---

## Comportamento

| Stato | Condizione | Effetto |
|-------|------------|---------|
| Agganciato | Entro 48 px dal fondo | Nuovi messaggi → auto-scroll |
| Staccato | Scroll verso storico | Nuovi messaggi altrui non spostano la vista |
| Riaggancio | Scroll al fondo o controllo UI | Riprende agganciato |

Regole:

1. Apertura chat → fondo (agganciato)
2. Messaggio inviato dall'utente → sempre fondo
3. Soglia: `ConversationScrollAnchor.defaultThreshold` = 48 px

---

## Implementazione

`AnchoredMessageList` — `ListView` reverse in `anchored_message_list.dart`.
