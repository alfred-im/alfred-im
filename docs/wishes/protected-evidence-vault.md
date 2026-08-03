# Vault di prove protette (custodia asimmetrica)

**Stato**: esplorazione — non promessa SDD, non implementato  
**Ultimo aggiornamento**: 2026-08-03  
**Categoria**: sicurezza, threat model, futuro opzionale

Documento per AI e progettazione. Descrive un **wish architetturale** distinto dalla chat cloud quotidiana di Alfred.

---

## Contesto e threat model

Alfred è **consent-first** e **feminist-informed**: l’allow list controlla *chi può far arrivare messaggi*. Un threat model diverso è la **coercizione fisica** e l’accesso al dispositivo in contesti di:

- abuso domestico o di coppia;
- crimini d’odio;
- violazioni dei diritti umani;
- attivismo sotto pressione.

In questi casi l’aggressore può:

- sbloccare o confiscare il telefono;
- cancellare foto, audio, chat dall’app o dalla galleria;
- intimidire la vittima per non denunciare.

La chat cloud «normale» (fonte di verità sul server, senza E2EE) **non** risolve questo scenario: chi ha accesso all’account o al device può leggere o eliminare ciò che è ancora leggibile localmente; il server oggi può leggere i contenuti.

**Obiettivo del wish**: un flusso in cui il dispositivo **non è custode completo** della prova decifrabile, e la cancellazione locale **non distrugge** l’archivio recuperabile per autorità o supporto legale.

---

## Principio: custodia asimmetrica

Termine interno Alfred (non standard di mercato). Combina due meccanismi che spesso si usano insieme:

| Meccanismo | Cosa fa | Effetto sul device |
|------------|---------|-------------------|
| **Crittografia asimmetrica (PKI)** | Cifratura con chiave **pubblica** del custode esterno; decifratura solo con chiave **privata** fuori dal telefono | Il file inviato è integro in cloud, ma **il device non può decifrarlo** dopo l’upload |
| **Secret sharing (es. Shamir)** | La chiave (o segreto) è divisa in **N** frammenti; servono **K** su N per ricomporre (threshold) | Sul telefono resta **un frammento insufficiente**; coercizione sul device non basta per aprire l’archivio |

Regola di fondo:

> Il potere di **cancellare o alterare** la prova definitiva viene ridotto sul dispositivo locale; il potere di **decifrare e consegnare** viene delegato a una rete esterna protetta (custode, K-of-N).

Questo è **ortogonale** all’E2EE end-to-end sulla chat generale: non richiede che tutti i messaggi siano segreti tra peer, ma che **un sotto-flusso** («prove», «segnalazione protetta») abbia custodia diversa.

---

## Esempi esterni (software reale)

Spesso non commercializzati come «custodia asimmetrica», ma applicano lo stesso principio.

### 1. ProofMode e eyeWitness to Atrocities

- **Chi**: Guardian Project; International Bar Association (eyeWitness).
- **Uso**: foto/video di abusi con metadati forensi (ora, posizione, firma).
- **Flusso**: capture → cifratura immediata con chiave pubblica di un ente (pool legali, associazione) → upload cloud.
- **Sul telefono**: la prova può essere nascosta o cancellata dall’aggressore; la copia cifrata in cloud resta intatta. Solo il custode con chiave privata può decifrare per denuncia o tribunale.
- **Riferimenti**: [ProofMode](https://guardianproject.info/apps/proofmode/) · [eyeWitness to Atrocities](https://eyewitness.global/)

### 2. App anti-violenza con threshold (Shamir)

- **Uso**: attivisti, giornalisti, vittime — prototipi e progetti di sicurezza digitale.
- **Flusso**: chiave di decifratura dell’archivio (chat, audio, foto) spezzata in N frammenti (es. 3); ricomposizione con K=2.
  - Frammento 1: app nascosta / vault sul telefono.
  - Frammento 2: centro antiviolenza o avvocato.
  - Frammento 3: contatto fidato o server sicuro.
- **Risultato**: accesso forzato al telefono → un solo frammento → **impossibile** decifrare o «distruggere per sempre» l’archivio senza le parti esterne.

### 3. GlobaLeaks e piattaforme whistleblowing

- **Uso**: segnalazioni istituzionali, minoranze, whistleblower.
- **Flusso**: submit cifrato con chiavi asimmetriche; contenuto «blindato» all’ingresso.
- **Accesso**: decifratura solo con **combinazione** di figure (es. magistrato + operatore di garanzia) per costruire il fascicolo per le autorità.
- **Riferimento**: [GlobaLeaks](https://www.globaleaks.org/)

### Tabella comparativa (esterni)

| Prodotto / pattern | PKI al submit | Threshold K-of-N | Focus |
|--------------------|---------------|------------------|--------|
| ProofMode | ✅ metadati + media | opzionale | Catena di custodia forense |
| eyeWitness | ✅ | — | Prove per tribunali |
| Shamir anti-violenza (prototipi) | spesso ✅ | ✅ | Coercizione sul device |
| GlobaLeaks | ✅ | spesso multi-operatore | Whistleblowing istituzionale |

---

## Limiti e rischi (da non omettere)

1. **Non invisibilità totale** — traffico, icona app, upload possono essere osservati; la difesa è crittografica e procedurale, non solo «nascosta».
2. **Il custode esterno è nuovo superficie** — compromissione o abuso del centro antiviolenza / server equivale a esposizione della prova (trade-off deliberato).
3. **Complessità operativa** — onboarding custodi, revoca, morte del contatto fidato, procedura per «aprire il fascicolo».
4. **Giurisdizione** — ammissibilità in tribunale: catena di custodia, consenso, normativa locale; il software non basta.
5. **Coercizione al momento del submit** — se l’aggressore impedisce l’invio, la cifratura post-upload non aiuta.

---

## Relazione con Alfred oggi

| Aspetto | Alfred attuale | Questo wish |
|---------|----------------|-------------|
| Modello dati | Cloud-first; server fonte di verità | Modulo **separato**; upload cifrato non decifrabile dal client |
| E2EE | ❌ fuori scope ([full-stack.md](../architecture/full-stack.md)) | Non E2EE su tutta la inbox; solo flusso «vault» |
| Allow list | ✅ blocca recapito non consentito | **Complementare**: chi può *arrivare* vs chi può *custodire prove* |
| Posizionamento | Consent-first, feminist-informed | Allineato: delega custodia a terzo fidato, non al device in casa |
| Federazione | Bridge pianificati | Vault potrebbe restare su istanza + custode Alfred o partner |

**Tensione architetturale**, non contraddizione: la chat quotidiana può restare cloud-first; un **bounded context** opzionale (`evidence` / `protected-report`) gestisce capture, cifratura, upload e threshold senza trasformare tutta la messaggistica in Signal.

---

## Applicabilità futura a Alfred (ipotesi)

### Cosa potrebbe essere (modulo opzionale)

- **Vault di prove** — foto, audio, brevi note con metadati forensi; non sostituisce la chat con un peer.
- **Submit one-way** — cifratura con chiave pubblica del custode (organizzazione partner o pool K-of-N) prima di persistenza leggibile.
- **Minimo sul device** — dopo upload confermato: opzione per rimuovere copia locale decifrabile; resta solo frammento threshold se previsto.
- **Procedura di apertura** — fuori dall’app: custode + vittima (o autorità) ricompongono K frammenti; non un tap «mostra tutto» sul telefono.

### Cosa non è (scope del wish)

- E2EE su tutte le conversazioni.
- Sostituto di denuncia, avvocato o PS — **affianca** con tooling.
- «App completamente nascosta» senza threat model UX (pressione psicologica, osservazione fisica).

### Domande aperte

1. **Chi sono i custodi?** — centri antiviolenza, legali, contatti fidati, solo server Alfred?
2. **K e N** — 2-of-3 fisso o configurabile per utente?
3. **Integrazione chat** — importare cronologia chat con peer X nel vault, o solo media capture dedicata?
4. **Catena di custodia** — hash, timestamp firmati, ProofMode-style metadata: obbligatori per valore legale?
5. **Partner operativi** — senza enti reali, K-of-N è solo crittografia senza procedura.
6. **Promessa SDD** — se implementato, quali comportamenti osservabili? (es. «dopo submit confermato, il file non è decifrabile sull’app»).

---

## Percorso possibile (non roadmap)

1. **Esplorazione** (questo documento) — threat model + esempi esterni.
2. **ADR o promessa draft** — se il prodotto adotta il modulo; definire confine con SYS-MAILBOX e media chat.
3. **Pilota con partner** — un custode reale (centro antiviolenza) prima di generalizzare K-of-N.
4. **Implementazione** — solo con promessa `approved` e modello (dominio → UML → statechart).

---

## Riferimenti

- [README.md](../../README.md) — consent-first, feminist-informed
- [server-as-reception.md](../decisions/server-as-reception.md) — modello cloud
- [SYS-RECEPTION](../specs/promises/system/SYS-RECEPTION.md) · [SURF-ALLOWLIST](../specs/surfaces/SURF-ALLOWLIST.md) — allow list
- [full-stack.md](../architecture/full-stack.md) — E2EE fuori scope
- [WISHLIST.md](../WISHLIST.md) — altre idee future (XMPP, UI)
- Shamir's Secret Sharing — [Wikipedia](https://en.wikipedia.org/wiki/Shamir%27s_Secret_Sharing)
