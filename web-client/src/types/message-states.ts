/**
 * Stati per asse — policy message-states.md
 * `none` = asse non applicabile a questo messaggio
 */

export type SendAxisState = 'none' | 'queued' | 'ui' | 'synced'
export type ReceiveAxisState = 'none' | 'ui' | 'synced'
export type ReadAxisState = 'none' | 'ui' | 'synced'

/** Livello spunta solo UI (non persistito come stato DB separato) */
export type CheckmarkLevel = 'pending' | 'failed' | 'sent' | 'reading'
