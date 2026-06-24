# Architettura - Analisi Tecniche

Analisi architetturali per comprensione sistema e decisioni implementative. Documento per AI.

> **Nota (2026-06-24)**: documentazione relativa al **client React legacy** (`web-client/`, tag `legacy/web-client-final`). Riferimento per il nuovo stack Flutter/Supabase.

## Documenti Disponibili

### Analisi MAM e Sincronizzazione
- **message-states.md** - **Policy spunte WhatsApp 3 livelli** + virtual UI + MAM-only DB (v2.1)
- **conversations-analysis.md** - Analisi tecnica recupero conversazioni XMPP
- **mam-global-strategy-explained.md** - Strategia MAM globale (query singola vs N query, vantaggi/svantaggi, implementazione)
- **mam-performance-long-term.md** - Performance MAM a lungo termine (scalabilità, grandi volumi, ottimizzazioni)
- **strategy-comparison.md** - Confronto strategie sync (ibrido vs globale vs per-contatto, decisione finale)

## Architettura Layer

Vedi `PROJECT_MAP.md` per dettagli completi.

```
UI Layer (Pages, Components)
    ↓
Context Layer (ConnectionContext, AuthContext, VirtualMessagesContext,
               ConversationsContext, MessagingContext)
    ↓
Services Layer (xmpp.ts, outbox-send.ts, mam-sync.ts, account-session.ts,
                messages.ts, sync-initializer.ts, conversations.ts, vcard.ts)
    ↓
Repository Layer (MessageRepository, OutboxRepository, ConversationRepository,
                  VCardRepository, MetadataRepository)
    ↓
Data Layer (IndexedDB per account + XMPP Server)
```

## Principi Chiave

### Architettura "Virtual UI + MAM-only DB" (v4.0 - giugno 2026)

1. **Listener = campanello**: aggiorna UI virtuale, schedula MAM (no write diretto DB messaggi)
2. **MAM = unico writer** messaggi e acknowledgement nel DB locale
3. **Spunte WhatsApp 3 livelli**: inviato (XMPP) + XEP-0184 + XEP-0333
4. **origin-id canonico** per marker e dedup (XEP-0359)
5. **Cache-First / Offline-First**
6. **Un account = un IndexedDB** (`conversations-db-{jid}`); storico conservato al logout (v2.2)

Vedi [message-states.md](./message-states.md) per policy completa.  
Vedi [../fixes/account-storage-isolation.md](../fixes/account-storage-isolation.md) per isolamento account.

### Evoluzione architetturale

| Aspetto | v2.0 (legacy) | v3.0 (dic 2025) | v4.0 (giu 2026) |
|---------|---------------|-----------------|-----------------|
| Punti di sync full | 15+ sparsi | 1 (AppInitializer) | 1 (AppInitializer) |
| Pull-to-refresh | Su tutte le pagine | Eliminato | Eliminato |
| Persistenza messaggi real-time | Sync completa | Save diretto listener | Campanello → MAM |
| Sync dopo evento campanello | Sempre (full) | Nessuna | MAM incrementale per conversazione |
| Spunte | — | XEP-0333 (2 livelli) | XEP-0184 + XEP-0333 (3 livelli) |
| Storage locale | — | DB condiviso | DB per account (v2.2) |
