# Delivery Receipts (XEP-0184) — Livello 2 (✓✓ grigie)

**Data**: 2026-06-16  
**XEP**: [XEP-0184: Message Delivery Receipts](https://xmpp.org/extensions/xep-0184.html)  
**Policy**: [message-states.md](../architecture/message-states.md)

---

## Ruolo nel modello WhatsApp

| Livello | XEP | UI |
|---------|-----|-----|
| 1 Inviato | XMPP send | ✓ grigia |
| **2 Consegnato** | **XEP-0184** | **✓✓ grigie** |
| 3 Lettura | XEP-0333 | ✓✓ blu |

XEP-0184 conferma che il messaggio è **arrivato sul client** del destinatario. È **separato** da XEP-0333 (visualizzato in chat).

---

## Invio (mittente)

Ogni messaggio in uscita richiede la ricevuta:

```typescript
client.sendMessage({
  to: contactJid,
  body: 'Ciao',
  type: 'chat',
  marker: { type: 'markable' },      // XEP-0333 livello 3
  receipt: { type: 'request' },      // XEP-0184 livello 2
})
```

Implementato in `outbox-send.ts`.

---

## Ricezione (destinatario)

Stanza.js, con `sendReceipts: true` (`xmpp.ts`), risponde **automaticamente** quando arriva un messaggio con `<request/>`:

```xml
<message to='mittente' from='destinatario'>
  <received xmlns='urn:xmpp:receipts' id='origin-id-del-messaggio'/>
</message>
```

Non serve codice aggiuntivo in `ChatPage` per inviare il receipt.

---

## Mittente riceve la conferma

```typescript
client.on('receipt', (message) => {
  setDeliveredUi(message.receipt.id)   // overlay UI
  scheduleConversationMamSync(...)    // MAM → DB
})
```

In `MessagingContext.tsx`.

---

## Persistenza MAM

Gli receipt archiviati vengono parsati in `mamResultToMessage()`:

```typescript
markerType: 'receipt'
markerFor: inner.receipt.id  // origin-id
```

`resolveCheckmarkLevel()` usa `markerType === 'receipt'` o `deliveredUi` → ✓✓ grigie.

---

## Note

- `receipt.id` deve essere l'**origin-id** del messaggio originale (allineato con fix MAM).
- XEP-0333 v1.0 ha **rimosso** il marker `received` proprio perché duplicava XEP-0184.
- Non confondere con XEP-0184 `request`/`received` e il vecchio `marker:received` di bozze 0333.
