# PROM-MESSAGE-REACTIONS — Reaction emoji su messaggi

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `PROM-MESSAGE-REACTIONS` |
| **Classe** | PRODUCT |
| **Status** | `approved` |
| **Ultima revisione** | 2026-08-07 |

Promessa di prodotto: tap su un messaggio apre un menu con picker emoji; la reaction scelta è visibile sulla bolla e sincronizzata tra i partecipanti. Dati append-only (`MessageReactionFact`).

---

## 1. Problema / obiettivo

L'utente esprime una reaction emoji su un messaggio in conversazione, la vede subito sulla bolla e la condivide con il peer (o i membri del gruppo) senza perdita di storico.

---

## 2. Promesse

### MUST

| ID | Promessa |
|----|----------|
| **PROM-MESSAGE-REACTIONS-001** | Tap su bolla messaggio con λ noto apre menu azioni con sezione reaction |
| **PROM-MESSAGE-REACTIONS-002** | Tap su emoji nel picker → `ApplyReaction`; la bolla mostra `ReactionSummary` aggregato |
| **PROM-MESSAGE-REACTIONS-003** | Picker emoji: catalogo completo caricato progressivamente allo scroll |
| **PROM-MESSAGE-REACTIONS-004** | Reaction ancorata a `logical_message_id` (λ), non a `messages.id` |
| **PROM-MESSAGE-REACTIONS-005** | Persistenza append-only: ogni azione = nuovo `MessageReactionFact` (`applied` / `withdrawn`) |
| **PROM-MESSAGE-REACTIONS-006** | Messaggio in attesa (senza λ) — reaction disabilitata |
| **PROM-MESSAGE-REACTIONS-007** | Aggiornamenti reaction da altri partecipanti via realtime sulla tabella fatti |
| **PROM-MESSAGE-REACTIONS-008** | Una reaction attiva per utente per messaggio; cambio emoji = nuovo fatto `applied` |

### SHOULD

| ID | Promessa |
|----|----------|
| **PROM-MESSAGE-REACTIONS-010** | Tap su reaction già attiva (propria) → `WithdrawReaction` |

### MUST NOT

| ID | Promessa |
|----|----------|
| **PROM-MESSAGE-REACTIONS-020** | `UPDATE` / `DELETE` su `message_reaction_facts` |
| **PROM-MESSAGE-REACTIONS-021** | Reaction su messaggio senza `logical_message_id` |

---

## 3. Modello (riferimento)

| Elemento | Artefatto |
|----------|-----------|
| Glossario / comandi | [docs/domain/messaging/](../../../domain/messaging/) |
| UML | [messaging-state.puml](../../../model/uml/messaging/messaging-state.puml), [seq-message-actions-reaction.puml](../../../model/uml/messaging/seq-message-actions-reaction.puml) |
| Schema / RPC | [contracts/schema.md](../../contracts/schema.md), [contracts/rpc.md](../../contracts/rpc.md) |
| Statechart client | [client/lib/machines/messaging/](../../../client/lib/machines/messaging/) |

---

## 4. Superfici conformi

| Superficie | Stato | File |
|------------|-------|------|
| SURF-CHAT | `approved` | [SURF-CHAT.md](../../surfaces/SURF-CHAT.md) |

---

## 5. Tracciabilità

| PROM-ID | Verifica |
|---------|----------|
| `PROM-MESSAGE-REACTIONS-001`–`008` | `client/test/unit/message_reactions_test.dart`, `message_actions_machine_test.dart` |
| Persistenza | `supabase/tests/message_reaction_facts_smoke.sql` |

---

## 6. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [registry.md](../../registry.md) | Indice promesse |
