/**
 * Opzioni condivise per la sincronizzazione MAM all'avvio.
 * boundary è il momento T: il listener copre da T in poi.
 * MAM usa T + margine di sovrapposizione (vedi getMamSyncEnd).
 */
export interface SyncOptions {
  boundary: Date
}
