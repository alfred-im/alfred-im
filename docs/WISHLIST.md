# Wishlist Funzionalità

**Ultimo aggiornamento**: 2026-06-28

Funzionalità **future** desiderate per Alfred (client Flutter + piattaforma + bridge).

---

## ✅ Già in Alpha (riferimento)

| Area | Stato | Documentazione |
|------|-------|----------------|
| Spunte cloud (inviato / consegnato server / lettura) | Parziale su interni | [server-as-reception.md](./decisions/server-as-reception.md), [alpha-full-stack.md](./architecture/alpha-full-stack.md) §2.9 |
| Chat testo, GIF, voice, location | ✅ | [voice-notes.md](./implementation/voice-notes.md), [location-sharing.md](./implementation/location-sharing.md) |
| Inbox message-centric | ✅ | [messages-only-inbox.md](./implementation/messages-only-inbox.md) |
| Federazione XMPP/Matrix | ⏸ Outbox only | [bridge-stateless.md](./decisions/bridge-stateless.md) |

Spunte federate (XEP-0184 / XEP-0333 via bridge): da implementare con i bridge Python.

---

## 🎯 Priorità Alta

### XEP-0280: Message Carbons
**Riferimento**: [XEP-0280](https://xmpp.org/extensions/xep-0280.html)

**Descrizione**: Sincronizzazione messaggi tra dispositivi multipli dello stesso account. Quando un utente invia un messaggio da un dispositivo, tutti gli altri dispositivi connessi ricevono una copia (carbon copy).

**Benefici**:
- Conversazioni sincronizzate su tutti i device
- Esperienza multi-device fluida
- Storia messaggi consistente

**Note implementazione**:
- Via bridge XMPP quando federazione attiva
- Stato su piattaforma Supabase (non cache locale)

---

## 🚀 Funzionalità in Roadmap

### XEP-0045: Multi-User Chat (MUC)
**Riferimento**: [XEP-0045](https://xmpp.org/extensions/xep-0045.html)

**Descrizione**: Chat di gruppo con più partecipanti, ruoli e moderazione.

**Benefici**:
- Supporto gruppi completi
- Gestione ruoli (admin, moderator, member)
- Stanze permanenti e temporanee

---

### XEP-0363: HTTP File Upload
**Riferimento**: [XEP-0363](https://xmpp.org/extensions/xep-0363.html)

**Descrizione**: Upload file tramite HTTP al server XMPP per condivisione in chat.

**Benefici**:
- Condivisione immagini, documenti, video
- Upload tramite HTTP (più semplice di in-band)
- Link permanenti ai file

**Note implementazione**:
- Richiede supporto server con storage
- Gestione thumbnail immagini
- Limite dimensioni file (configurabile server)

---

### XEP-0308: Last Message Correction
**Riferimento**: [XEP-0308](https://xmpp.org/extensions/xep-0308.html)

**Descrizione**: Modifica dell'ultimo messaggio inviato (come "Edit" su Telegram).

**Benefici**:
- Correzione typo senza eliminare
- UX migliorata
- Storia modifiche

---

### XEP-0092: Software Version
**Riferimento**: [XEP-0092](https://xmpp.org/extensions/xep-0092.html)

**Descrizione**: Query informazioni su versione software client/server.

**Benefici**:
- Debugging interoperabilità
- Statistiche utilizzo
- Feature detection

---

## 🎨 Feature UI/UX

### Emoji Picker
**Descrizione**: Selettore emoji nativo nell'input messaggi.

**Benefici**:
- UX messaggistica moderna
- Supporto completo Unicode emoji
- Categorie e ricerca

---

### Voice/Video Calls
**Riferimenti**: [XEP-0166 (Jingle)](https://xmpp.org/extensions/xep-0166.html), [XEP-0167 (Jingle RTP)](https://xmpp.org/extensions/xep-0167.html)

**Descrizione**: Chiamate vocali e videochiamate peer-to-peer.

**Benefici**:
- Comunicazione real-time completa
- Alternative a chat testuale
- WebRTC integration

**Note implementazione**:
- Complessità alta
- Richiede WebRTC
- Gestione NAT/STUN/TURN
- Segnalazione tramite Jingle

---

## 📊 Metriche e Priorità (solo future)

| Funzionalità | Priorità | Complessità | Impatto UX | Supporto Server |
|--------------|----------|-------------|------------|-----------------|
| XEP-0280 Carbons | ⭐⭐⭐ Alta | Media | Alto | ✅ Ampio |
| XEP-0308 Message Correction | ⭐⭐ Media | Bassa | Medio | ✅ Buono |
| XEP-0363 File Upload | ⭐⭐⭐ Alta | Media | Alto | ✅ Buono |
| XEP-0045 MUC | ⭐⭐ Media | Alta | Alto | ✅ Ampio |
| Emoji Picker | ⭐ Bassa | Bassa | Basso | N/A |
| Voice/Video | ⭐⭐ Media | Molto Alta | Alto | ⚠️ Limitato |

---

## 📝 Note Generali

### Compatibilità Server
La maggior parte delle XEP richiede supporto server. Prima di implementare una feature, verificare supporto lato bridge e homeserver federati.

### Testing
Ogni nuova XEP deve includere test bridge, integrazione piattaforma e documentazione in `docs/implementation/`.

### Riferimenti Utili
- **XEP Index**: https://xmpp.org/extensions/
- **Compliance Suites**: https://xmpp.org/extensions/xep-0459.html (2024)

---

**Prossimi Passi**:
1. Implementare XEP-0280 (Carbons) per sync multi-device
2. Aggiungere XEP-0308 (Message Correction) per edit messaggi
3. Valutare XEP-0363 (File Upload) dopo testing server
- Esperienza multi-device fluida
- Storia messaggi consistente

**Note implementazione**:
- Via bridge XMPP quando federazione attiva
- Stato su piattaforma Supabase (non cache locale)

---

## 🚀 Funzionalità in Roadmap