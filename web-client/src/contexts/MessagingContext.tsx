/* eslint-disable react-refresh/only-export-components */
import { createContext, useContext, useEffect, useCallback, useRef } from 'react'
import type { ReactNode } from 'react'
import type { ReceivedMessage } from 'stanza/protocol'
import { useConnection } from './ConnectionContext'
import { useConversations } from './ConversationsContext'
import { messageRepository } from '../services/repositories'
import { conversationRepository } from '../services/repositories'
import { normalizeJID } from '../utils/jid'
import type { Message } from '../services/conversations-db'

type MessageCallback = (message: ReceivedMessage) => void

interface MessagingContextType {
  subscribeToMessages: (callback: MessageCallback) => () => void
}

const MessagingContext = createContext<MessagingContextType | undefined>(undefined)

/**
 * Helper per estrarre JID del contatto da un messaggio
 */
function extractContactJid(message: ReceivedMessage, myJid: string): string {
  const myBareJid = normalizeJID(myJid)
  const from = message.from || ''
  const to = message.to || ''
  
  // Se il messaggio è da me, il contatto è il destinatario
  if (from.toLowerCase().startsWith(myBareJid.toLowerCase())) {
    return normalizeJID(to)
  }
  // Altrimenti il contatto è il mittente
  return normalizeJID(from)
}

/**
 * MessagingProvider - Gestisce messaggi in arrivo real-time
 * 
 * ARCHITETTURA SEMPLIFICATA:
 * - NON fa più sync completa dopo ogni messaggio
 * - Salva direttamente il messaggio nel DB
 * - L'observer del MessageRepository notifica automaticamente la UI
 */
export function MessagingProvider({ children }: { children: ReactNode }) {
  const { client, isConnected, jid } = useConnection()
  const { refreshConversation } = useConversations()
  const messageCallbacks = useRef<Set<MessageCallback>>(new Set())

  // Gestione messaggi in arrivo - SEMPLIFICATO: solo salvataggio diretto
  useEffect(() => {
    if (!client || !isConnected || !jid) return

    const handleMessage = async (message: ReceivedMessage) => {
      console.log('📨 Messaggio ricevuto:', { from: message.from, body: message.body?.substring(0, 50) })
      
      if (!message.body) {
        console.log('   ⚠️ Messaggio senza body, ignorato')
        return
      }

      try {
        // Estrai info messaggio
        const contactJid = extractContactJid(message, jid)
        const myBareJid = normalizeJID(jid)
        const from = message.from || ''
        const isFromMe = from.toLowerCase().startsWith(myBareJid.toLowerCase())

        // Crea oggetto messaggio
        const messageToSave: Message = {
          messageId: message.id || `msg_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`,
          conversationJid: normalizeJID(contactJid),
          body: message.body,
          timestamp: message.delay?.timestamp || new Date(),
          from: isFromMe ? 'me' : 'them',
          status: 'sent',
        }

        // Salva nel DB (questo triggera automaticamente l'observer)
        await messageRepository.saveAll([messageToSave])
        console.log('   ✅ Messaggio salvato nel DB')

        // Aggiorna conversazione con ultimo messaggio
        await conversationRepository.update(contactJid, {
          lastMessage: {
            body: messageToSave.body,
            timestamp: messageToSave.timestamp,
            from: messageToSave.from,
            messageId: messageToSave.messageId,
          },
          updatedAt: messageToSave.timestamp,
        })

        // Se messaggio è da altri, incrementa unread
        if (!isFromMe) {
          await conversationRepository.incrementUnread(contactJid)
        }

        // Aggiorna lista conversazioni
        await refreshConversation(contactJid)

        // Notifica subscribers
        messageCallbacks.current.forEach((callback) => {
          callback(message)
        })
      } catch (error) {
        console.error('❌ Errore nel salvataggio messaggio:', error)
      }
    }

    // XEP-0333: Listener per marker 'displayed'
    const handleDisplayedMarker = async (message: ReceivedMessage) => {
      if (!message.marker?.id) return
      
      console.log('✓✓ Marker displayed ricevuto per messaggio:', message.marker.id)
      
      try {
        const contactJid = normalizeJID(message.from || '')
        
        // Salva marker come messaggio speciale
        const markerMessage: Message = {
          messageId: `marker_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`,
          conversationJid: contactJid,
          body: '',
          timestamp: new Date(),
          from: 'them',
          status: 'sent',
          markerType: 'displayed',
          markerFor: message.marker.id,
        }
        
        await messageRepository.saveAll([markerMessage])
        console.log('   ✅ Marker displayed salvato nel DB')
      } catch (error) {
        console.error('❌ Errore nel salvataggio marker displayed:', error)
      }
    }

    // XEP-0333: Listener per marker 'acknowledged'
    const handleAcknowledgedMarker = async (message: ReceivedMessage) => {
      if (!message.marker?.id) return
      
      console.log('✓✓ Marker acknowledged ricevuto per messaggio:', message.marker.id)
      
      try {
        const contactJid = normalizeJID(message.from || '')
        
        // Salva marker come messaggio speciale
        const markerMessage: Message = {
          messageId: `marker_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`,
          conversationJid: contactJid,
          body: '',
          timestamp: new Date(),
          from: 'them',
          status: 'sent',
          markerType: 'acknowledged',
          markerFor: message.marker.id,
        }
        
        await messageRepository.saveAll([markerMessage])
        console.log('   ✅ Marker acknowledged salvato nel DB')
      } catch (error) {
        console.error('❌ Errore nel salvataggio marker acknowledged:', error)
      }
    }

    client.on('message', handleMessage)
    client.on('marker:displayed', handleDisplayedMarker)
    client.on('marker:acknowledged', handleAcknowledgedMarker)

    return () => {
      client.off('message', handleMessage)
      client.off('marker:displayed', handleDisplayedMarker)
      client.off('marker:acknowledged', handleAcknowledgedMarker)
    }
  }, [client, isConnected, jid, refreshConversation])

  const subscribeToMessages = useCallback((callback: MessageCallback) => {
    messageCallbacks.current.add(callback)
    
    // Ritorna funzione per unsubscribe
    return () => {
      messageCallbacks.current.delete(callback)
    }
  }, [])

  return (
    <MessagingContext.Provider
      value={{
        subscribeToMessages,
      }}
    >
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
