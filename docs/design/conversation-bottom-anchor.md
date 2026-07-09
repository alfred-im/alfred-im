# Aggancio al fondo della conversazione

> **SDD**: contratto non ancora distillato in promessa PRODUCT. Per nuovo lavoro usare [registry.md](../specs/registry.md) (backlog `PROM-BOTTOM-ANCHOR`). Evidenza UX PR #125.

**Data**: 2026-06-27  
**Status**: Evidenza implementata — **non** contratto v2  
**Categoria**: Chat, scroll, UX  
**Correlata**: [no-internal-external-chat-distinction.md](../decisions/no-internal-external-chat-distinction.md)

---

## Concept

L’**aggancio al fondo** è il comportamento che mantiene la vista conversazione ancorata all’ultimo messaggio quando l’utente è «in fondo», e la libera quando legge lo storico verso l’alto.

Tre stati:

| Stato | Condizione | Comportamento |
|-------|------------|---------------|
| **Agganciato** | Scroll entro soglia dal fondo | Nuovi messaggi portano automaticamente la vista al fondo |
| **Staccato** | Utente ha scrollato verso lo storico | Nuovi messaggi **non** spostano la vista |
| **Riaggancio** | Scroll manuale al fondo o tap sul controllo UI | Riprende lo stato agganciato |

---

## Regole di comportamento

1. **Apertura chat / fine caricamento messaggi** → vista al fondo (agganciato).
2. **Messaggio in arrivo** mentre agganciato → auto-scroll al fondo.
3. **Messaggio inviato dall’utente** → sempre scroll al fondo (riaggancio forzato), anche se era staccato.
4. **Scroll verso lo storico** → stacco; la posizione resta stabile su nuovi messaggi altrui.
5. **Riaggancio manuale** → scroll animato al fondo; azzera contatore messaggi pendenti.

Soglia aggancio: **48 px** dal fondo (`ConversationScrollAnchor.defaultThreshold`).

---

## UI correlata

Quando **staccato**:

- Pulsante circolare con freccia verso il basso, sopra la barra di input (angolo destro).
- Se sono arrivati messaggi mentre staccato: **badge** con conteggio sul pulsante.
- Tap sul pulsante → riaggancio animato.

Nessun altro elemento UI distinto per tipo di conversazione.

---

## Vincolo: tutte le chat

L’aggancio è **identico per ogni conversazione**. Vietata qualsiasi distinzione interna/esterna — vedi [no-internal-external-chat-distinction.md](../decisions/no-internal-external-chat-distinction.md).

Un solo widget, un solo percorso logico nel client.

---

## Implementazione Flutter (scope attuale)

| Elemento | Percorso |
|----------|----------|
| Logica pura (soglia, decisioni scroll) | `client/lib/utils/conversation_scroll_anchor.dart` |
| Lista messaggi + scroll + pulsante | `client/lib/widgets/anchored_message_list.dart` |
| Integrazione vista chat | `client/lib/widgets/chat_panel.dart` |

**Tecnica**: `ListView.builder` con `reverse: true`; fondo = `pixels <= threshold`. Messaggi in ordine cronologico nel modello; indice invertito in build.

---

## Riferimenti

- [no-internal-external-chat-distinction.md](../decisions/no-internal-external-chat-distinction.md)
- [full-stack.md](../architecture/full-stack.md) — §2.10 Aggancio al fondo
- `PROJECT_MAP.md` — sezione client Flutter / chat
