/**
 * Coordina il passaggio di consegne tra sincronizzazione MAM e listener real-time.
 *
 * All'avvio della sync:
 * 1. Salva il momento T (boundary)
 * 2. Attiva il listener (messaggi da T in poi)
 * 3. La sync scarica il passato via MAM fino a T + margine di sovrapposizione
 *    (per skew orologi; i doppioni in overlap sono eliminati per messageId)
 */

import { SYNC } from '../config/constants'

export interface SyncBoundaryState {
  boundary: Date | null
  isListenerActive: boolean
}

/**
 * Fine intervallo MAM: T + overlap. Il listener resta ancorato a T.
 */
export function getMamSyncEnd(boundary: Date): Date {
  return new Date(boundary.getTime() + SYNC.BOUNDARY_OVERLAP_MS)
}

type SyncBoundaryListener = (state: SyncBoundaryState) => void

class SyncBoundaryService {
  private boundary: Date | null = null
  private isListenerActive = false
  private listeners = new Set<SyncBoundaryListener>()

  /**
   * Inizia il handoff: salva T e attiva il listener prima della sync.
   */
  beginHandoff(boundary: Date = new Date()): Date {
    this.boundary = boundary
    this.isListenerActive = true
    this.notify()
    console.log(`🕐 Sync boundary impostato: ${boundary.toISOString()}`)
    return boundary
  }

  getBoundary(): Date | null {
    return this.boundary
  }

  isActive(): boolean {
    return this.isListenerActive
  }

  getState(): SyncBoundaryState {
    return {
      boundary: this.boundary,
      isListenerActive: this.isListenerActive,
    }
  }

  reset(): void {
    this.boundary = null
    this.isListenerActive = false
    this.notify()
  }

  subscribe(listener: SyncBoundaryListener): () => void {
    this.listeners.add(listener)
    listener(this.getState())
    return () => {
      this.listeners.delete(listener)
    }
  }

  private notify(): void {
    const state = this.getState()
    this.listeners.forEach((listener) => {
      try {
        listener(state)
      } catch (error) {
        console.error('Errore nel listener sync boundary:', error)
      }
    })
  }
}

export const syncBoundaryService = new SyncBoundaryService()
