# Glossario — contesto federation

**Bounded context:** `federation`  
**Ultima revisione:** 2026-07-27  
**Stato runtime:** bridge stub (health only); modello documentato per implementazione futura.

---

## Linguaggio ubiquo

| Termine | Definizione |
|---------|-------------|
| **Federation** | Messaggistica verso/da server esterni (XMPP, Matrix) tramite bridge su Fly.io. |
| **Contact protocol** | Routing backend: internal, xmpp, matrix — invisibile in inbox UI standard. |
| **Bridge (stateless)** | Processo bridge senza stato business locale — vedi [bridge-stateless.md](../../decisions/bridge-stateless.md). |
| **Platform truth** | Piattaforma tiene outbox, watermark sync, job bridge, mapping identità. |
| **Federated outbox** | Stesso bus outbox; protocollo esterno; consumer = bridge worker (non delivery sync internal). |
| **Queued (federato)** | Outbox accodato; su internal worker immediato; su federato resta fino a claim bridge. |
| **External id** | Id messaggio percepito dall'altro sistema — mapping ack spunte. |
| **Sync cursor** | Watermark sync per coppia profilo/protocollo. |
| **Bridge job** | Coda lavori bridge complementare a outbox (handshake, sync conversazione). |
| **Federated facade** | Bridge traduce protocollo esterno ↔ modello caselle Alfred (copie archivio + λ). |
| **Inbound federato** | Messaggio esterno → bridge → copia destinatario Alfred (+ gate reception). |
| **Outbound federato** | Client → confine account → outbox → bridge → server esterno del peer. |
| **Federated ack** | Ack recapito/lettura esterno → aggiorna spunte copia mittente Alfred. |

---

## Confini

| Contesto | Relazione |
|----------|-----------|
| **delivery** | Internal usa delivery worker sincrono; federato riusa outbox, consumer diverso. |
| **messaging** | Client invia sempre via piattaforma; non parla direttamente ai bridge. |
| **reception** | Gate allow list applicato anche su materializzazione inbound bridge. |
| **contacts** | Rubrica salva indirizzi esterni per routing futuro. |

---

## Invarianti (target)

1. Bridge **non** conservano stato autorevole — solo cache volatile rigenerabile.
2. Stesso modello caselle: copie archivio indipendenti, λ per correlazione, spunte come segnali.
3. Più repliche bridge possono processare job idempotenti con lock su piattaforma.
4. Id esterno + λ risolvono ack protocollo esterno sulla copia mittente Alfred.
5. Client web → **solo** piattaforma; mai connessione diretta XMPP/Matrix dal client.
