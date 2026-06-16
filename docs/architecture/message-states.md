# Stati del messaggio — Policy di sviluppo

**Versione**: 1.1  
**Data**: 2026-06-16  
**Stato**: Policy attiva per implementazione

---

## Principio fondamentale

Ogni flusso ha **due fasi**:

1. **`ui`** — aggiornamento grafico immediato (campanello / azione utente)
2. **`synced`** — dato autoritativo da MAM nel database locale

Il listener real-time **non scrive il corpo dei messaggi nel DB**.  
Solo **MAM** persiste messaggi e marker nel database messaggi.

---

## Tre flussi paralleli

| Flusso | `ui` (campanello / azione) | `synced` (MAM → DB) |
|--------|----------------------------|---------------------|
| **Invio** | Messaggio mostrato in chat; outbox se offline | MAM conferma e salva |
| **Ricezione** | Campanello → messaggio in UI | MAM scarica e salva |
| **Lettura** | Campanello marker → spunta in UI | MAM allinea marker nel DB |

`none` su un asse = quell'asse non si applica al messaggio (es. ricezione su messaggio inviato da te).

### Invio (messaggi tuoi)

```
queued → ui → synced
   ↑ send_failed / offline (outbox persistito)
```

- **`queued`**: in outbox IndexedDB; sopravvive a disconnessione
- **`ui`**: visibile in chat prima di MAM
- **`synced`**: presente nel DB da MAM

### Ricezione (messaggi in arrivo)

```
ui → synced
```

### Lettura (spunte su messaggi inviati da te)

```
ui → synced
```

---

## Spunte in UI (solo grafica)

Due livelli visivi, allineati a **XEP-0333 v1.0** (solo `markable` + `displayed`):

| Livello UI | Aspetto | Significato |
|------------|---------|-------------|
| **Inviato** | ✓ grigia | Messaggio accettato dal server |
| **Lettura** | ✓✓ blu | L'altro ha visualizzato il messaggio (`displayed`) |

### Cosa NON implementiamo

| Marker | Stato in XEP-0333 v1.0 | Nostra policy |
|--------|------------------------|---------------|
| `received` | **Rimosso** (2024) | Ignorato in UI; stanza.js può ancora inviarlo in automatico verso altri client |
| `acknowledged` | **Rimosso** (2024) | Non gestito |
| XEP-0184 delivery receipts | Protocollo separato | Non usato |

### Mapping protocollo → UI

| Marker XMPP | Stato UI spunta |
|-------------|-----------------|
| — (solo inviato) | ✓ grigia |
| `displayed` | ✓✓ blu |

### Stato implementazione spunte

| Funzionalità | Stato |
|--------------|-------|
| ✓ grigia (inviato) | ✅ |
| ✓✓ blu (`displayed`) | ✅ |
| `received` / `acknowledged` | ❌ Fuori scope |

---

## Dove vive ogni dato

| Layer | Contenuto |
|-------|-----------|
| **Outbox** (IndexedDB) | Messaggi in uscita: `queued`, `sending`, `failed`; `stanzaId` = origin-id XMPP |
| **UI virtuale** (React) | Messaggi e overlay spunte in fase `ui` |
| **DB messaggi** (IndexedDB) | Solo dati `synced` da MAM; `messageId` = **origin-id** (non archive UID MAM) |
| **Metadata sync** | Watermark / token per query MAM |

### Identificatori messaggio

- **`messageId` (locale)** = `origin-id` (XEP-0359) se presente nello stanza archiviato, altrimenti `id` stanza, ultimo fallback archive UID MAM.
- **`mamArchiveId`** = UID riga archivio MAM (`MAMResult.id`); usato solo per migrazione/paginazione, non per marker.
- **Marker XEP-0333** referenziano l'origin-id del messaggio target → stesso valore di `messageId` canonico.

---

## Trigger sync MAM (campanello)

All'evento real-time (messaggio, marker):

1. Aggiorna UI (`ui`)
2. Schedula fetch MAM con `start = ora − 2 secondi` (debounce per conversazione)
3. MAM salva nel DB → `synced`
4. UI sostituisce / rimuove il virtuale; overlay spunte allineati al DB

---

## Riferimenti

- [sync-system-complete.md](../implementation/sync-system-complete.md) — Sync-once + listen
- [chat-markers-xep-0333.md](../implementation/chat-markers-xep-0333.md) — Marker XEP-0333 (da allineare a questa policy)
