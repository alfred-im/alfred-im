# Architettura - Analisi Tecniche

Analisi architetturali per comprensione sistema e decisioni implementative. Documento per AI.

## Documenti Disponibili

### Analisi MAM e Sincronizzazione
- **message-states.md** - **Policy spunte WhatsApp 3 livelli** + virtual UI + MAM-only DB (v2.0)
- **conversations-analysis.md** - Analisi tecnica recupero conversazioni XMPP
- **mam-global-strategy-explained.md** - Strategia MAM globale (query singola vs N query, vantaggi/svantaggi, implementazione)
- **mam-performance-long-term.md** - Performance MAM a lungo termine (scalabilità, grandi volumi, ottimizzazioni)
- **strategy-comparison.md** - Confronto strategie sync (ibrido vs globale vs per-contatto, decisione finale)

## Architettura Layer

Vedi `PROJECT_MAP.md` per dettagli completi.

```
UI Layer (Pages, Components)
    ↓
Context Layer (XmppContext, ConversationsContext, MessagingContext, AuthContext, ConnectionContext)
    ↓
Services Layer (xmpp.ts, messages.ts, conversations.ts, sync-initializer.ts, vcard.ts)
    ↓
Repository Layer (ConversationRepository, MessageRepository, VCardRepository, MetadataRepository)
    ↓
Data Layer (IndexedDB + XMPP Server)
```

## Principi Chiave

### Architettura "Virtual UI + MAM-only DB" (v4.0 - giugno 2026)

1. **Listener = campanello**: aggiorna UI virtuale, schedula MAM (no write diretto DB messaggi)
2. **MAM = unico writer** messaggi e acknowledgement nel DB locale
3. **Spunte WhatsApp 3 livelli**: inviato (XMPP) + XEP-0184 + XEP-0333
4. **origin-id canonico** per marker e dedup (XEP-0359)
5. **Cache-First / Offline-First**

Vedi [message-states.md](./message-states.md) per policy completa.

### Differenze con Architettura Precedente

| Aspetto | Prima (v2.0) | Ora (v3.0) | Miglioramento |
|---------|--------------|------------|---------------|
| Punti di sync | 15+ sparsi | 1 (AppInitializer) | **-93%** |
| Pull-to-refresh | Su tutte le pagine | Eliminato | **-100%** |
| Sync dopo messaggio | Sempre | Mai | **-100%** |
| Query server/giorno | Centinaia | ~1-5 | **-95%** |
| Righe codice sync | ~1700 | ~530 | **-70%** |
