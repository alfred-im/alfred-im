/* eslint-disable react-refresh/only-export-components */
import { createContext, useContext, useEffect, useCallback, useRef } from 'react'
import type { ReactNode } from 'react'
import type { ReceivedMessage } from 'stanza/protocol'
import { useConnection } from './ConnectionContext'
import { useConversations } from './ConversationsContext'
import { useVirtualMessages } from './VirtualMessagesContext'
import { conversationRepository } from '../services/repositories'
import { normalizeJID } from '../utils/jid'
import { syncBoundaryService } from '../services/sync-boundary'
import { scheduleConversationMamSync } from '../services/mam-sync'
import { extractCanonicalMessageIdFromStanza } from '../utils/message-id'

type MessageCallback = (message: ReceivedMessage) => void

interface MessagingContextType {
  subscribeToMessages: (callback: MessageCallback) => () => void
}

const MessagingContext = createContext<MessagingContextType | undefined>(undefined)

function extractContactJid(message: ReceivedMessage, myJid: string): string {
  const myBareJid = normalizeJID(myJid)
  const from = message.from || ''
  const to = message.to || ''

  if (from.toLowerCase().startsWith(myBareJid.toLowerCase())) {
    return normalizeJID(to)
  }
  return normalizeJID(from)
}

/**
 * Listener = campanello: aggiorna UI virtuale e schedula MAM.
 * Il DB messaggi è scritto solo da MAM (mam-sync.ts).
 */
export function MessagingProvider({ children }: { children: ReactNode }) {
  const { client, isConnected, jid } = useConnection()
  const { refreshConversation } = useConversations()
  const { addIncomingVirtual, setReadingUi, setDeliveredUi } = useVirtualMessages()
  const messageCallbacks = useRef<Set<MessageCallback>>(new Set())

  useEffect(() => {
    if (!client || !isConnected || !jid) return

    const handleMessage = async (message: ReceivedMessage) => {
      if (!syncBoundaryService.isActive()) return
      if (!message.body) return

      try {
        const contactJid = extractContactJid(message, jid)
        const myBareJid = normalizeJID(jid)
        const from = message.from || ''
        const isFromMe = from.toLowerCase().startsWith(myBareJid.toLowerCase())
        const timestamp = message.delay?.timestamp || new Date()
        const normalizedContactJid = normalizeJID(contactJid)

        const virtualId = addIncomingVirtual(
          normalizedContactJid,
          message.body,
          timestamp
        )

        await conversationRepository.update(normalizedContactJid, {
          jid: normalizedContactJid,
          lastMessage: {
            body: message.body,
            timestamp,
            from: isFromMe ? 'me' : 'them',
            messageId: extractCanonicalMessageIdFromStanza(message) || virtualId,
          },
          updatedAt: timestamp,
        })

        if (!isFromMe) {
          await conversationRepository.incrementUnread(normalizedContactJid)
        }

        await refreshConversation(normalizedContactJid)
        scheduleConversationMamSync(client, normalizedContactJid, 'message-bell')

        messageCallbacks.current.forEach((callback) => callback(message))
      } catch (error) {
        console.error('❌ Errore gestione campanello messaggio:', error)
      }
    }

    const handleDisplayedMarker = (message: ReceivedMessage) => {
      if (!syncBoundaryService.isActive() || !message.marker?.id) return

      const contactJid = normalizeJID(message.from || '')
      setReadingUi(message.marker.id)
      scheduleConversationMamSync(client, contactJid, 'marker-displayed')
    }

    const handleReceipt = (message: ReceivedMessage) => {
      if (!syncBoundaryService.isActive() || !message.receipt?.id) return

      const contactJid = normalizeJID(message.from || '')
      setDeliveredUi(message.receipt.id)
      scheduleConversationMamSync(client, contactJid, 'receipt')
    }

    client.on('message', handleMessage)
    client.on('marker:displayed', handleDisplayedMarker)
    client.on('receipt', handleReceipt)

    return () => {
      client.off('message', handleMessage)
      client.off('marker:displayed', handleDisplayedMarker)
      client.off('receipt', handleReceipt)
    }
  }, [client, isConnected, jid, refreshConversation, addIncomingVirtual, setReadingUi, setDeliveredUi])

  const subscribeToMessages = useCallback((callback: MessageCallback) => {
    messageCallbacks.current.add(callback)
    return () => {
      messageCallbacks.current.delete(callback)
    }
  }, [])

  return (
    <MessagingContext.Provider value={{ subscribeToMessages }}>
      {children}
    </MessagingContext.Provider>
  )
}

export function useMessaging() {
  const context = useContext(MessagingContext)
  if (context === undefined) {
    throw new Error('useMessaging deve essere usato dentro MessagingProvider')
  }
  return context
}
