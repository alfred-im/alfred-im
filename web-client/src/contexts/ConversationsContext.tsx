/* eslint-disable react-refresh/only-export-components */
import { createContext, useContext, useState, useEffect, useCallback } from 'react'
import type { ReactNode } from 'react'
import type { Conversation } from '../services/conversations-db'
import { conversationRepository } from '../services/repositories'
import { normalizeJID } from '../utils/jid'

interface ConversationsContextType {
  conversations: Conversation[]
  isLoading: boolean
  error: string | null
  reloadFromDB: () => Promise<void>
  refreshConversation: (jid: string) => Promise<void>
  markAsRead: (jid: string) => Promise<void>
}

const ConversationsContext = createContext<ConversationsContextType | undefined>(undefined)

/**
 * ConversationsProvider - Gestisce stato conversazioni
 * 
 * ARCHITETTURA SEMPLIFICATA:
 * - NON carica più dal server (sync gestita da AppInitializer)
 * - Carica solo da cache locale
 * - Si aggiorna automaticamente quando cambiano i dati (via refreshConversation)
 * - NO più pull-to-refresh o refreshAll
 */
export function ConversationsProvider({ children }: { children: ReactNode }) {
  const [conversations, setConversations] = useState<Conversation[]>([])
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  // Carica conversazioni dalla cache al mount
  useEffect(() => {
    const loadFromCache = async () => {
      setIsLoading(true)
      try {
        const cached = await conversationRepository.getAll()
        setConversations(cached)
      } catch (err) {
        console.error('Errore caricamento cache conversazioni:', err)
        setError(err instanceof Error ? err.message : 'Errore nel caricamento')
      } finally {
        setIsLoading(false)
      }
    }

    loadFromCache()
  }, [])

  // Ricarica conversazioni dal DB (chiamato dopo aggiornamenti)
  const reloadFromDB = useCallback(async () => {
    try {
      const updated = await conversationRepository.getAll()
      setConversations(updated)
    } catch (error) {
      console.error('Errore ricaricamento conversazioni:', error)
    }
  }, [])

  const sortConversations = (items: Conversation[]) =>
    [...items].sort(
      (a, b) => b.lastMessage.timestamp.getTime() - a.lastMessage.timestamp.getTime()
    )

  const refreshConversation = useCallback(async (jid: string) => {
    try {
      const normalizedJid = normalizeJID(jid)
      const updated = await conversationRepository.getByJid(normalizedJid)
      if (!updated) return

      setConversations((prev) => {
        const index = prev.findIndex((conv) => conv.jid === normalizedJid)
        if (index === -1) {
          return sortConversations([updated, ...prev])
        }

        const next = [...prev]
        next[index] = updated
        return sortConversations(next)
      })
    } catch (error) {
      console.error('Errore aggiornamento conversazione:', error)
    }
  }, [])

  // Marca conversazione come letta
  const markAsRead = useCallback(async (conversationJid: string) => {
    try {
      await conversationRepository.markAsRead(conversationJid)
      await refreshConversation(conversationJid)
    } catch (error) {
      console.error('Errore marcatura conversazione:', error)
    }
  }, [refreshConversation])

  return (
    <ConversationsContext.Provider
      value={{
        conversations,
        isLoading,
        error,
        reloadFromDB,
        refreshConversation,
        markAsRead,
      }}
    >
      {children}
    </ConversationsContext.Provider>
  )
}

export function useConversations() {
  const context = useContext(ConversationsContext)
  if (context === undefined) {
    throw new Error('useConversations deve essere usato dentro ConversationsProvider')
  }
  return context
}
