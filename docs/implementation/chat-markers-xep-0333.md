# Chat Markers (XEP-0333) — Livello 3 (✓✓ blu)

**Data aggiornamento**: 2026-06-16  
**XEP**: [XEP-0333 v1.0 — Displayed Markers](https://xmpp.org/extensions/xep-0333.html)  
**Policy canonica**: [message-states.md](../architecture/message-states.md)

---

## Ruolo nel modello WhatsApp a 3 livelli

| Livello | Meccanismo | UI |
|---------|------------|-----|
| 1 | Invio XMPP | ✓ grigia |
| 2 | [XEP-0184](./delivery-receipts-xep-0184.md) | ✓✓ grigie |
| **3** | **XEP-0333 `displayed`** | **✓✓ blu** |

XEP-0333 v1.0 definisce **solo** `markable` + `displayed`. I marker `received` e `acknowledged` delle bozze vecchie sono **rimossi** (2024).

---

## Invio (mittente)

```typescript
marker: { type: 'markable' }
```

In `outbox-send.ts` insieme a `receipt: { type: 'request' }`.

---

## Ricezione (destinatario)

Quando apri la chat, `ChatPage.tsx` invia `displayed` per ogni messaggio da loro non ancora marcato:

```typescript
client.markDisplayed({
  id: msg.messageId,  // origin-id
  from: jid,
  type: 'chat',
})
```

---

## Mittente riceve la conferma di lettura

```typescript
client.on('marker:displayed', (message) => {
  setReadingUi(message.marker.id)
  scheduleConversationMamSync(...)
})
```

---

## Architettura v4.0

- Listener = campanello → overlay UI → MAM (unico writer DB)
- MAM persiste `markerType: 'displayed'`, `markerFor: origin-id`
- `utils/checkmark.ts`: `reading` ha priorità su `delivered` e `sent`

---

## Riferimenti

- [delivery-receipts-xep-0184.md](./delivery-receipts-xep-0184.md) — livello 2
- [message-states.md](../architecture/message-states.md) — policy completa
