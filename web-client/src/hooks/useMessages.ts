import { useState, useEffect, useRef, useCallback, useMemo } from 'react'
import type { Agent } from 'stanza'
import {
  sendMessage as sendMessageService,
  applySelfChatLogic,
  clearOutboxIfSynced,
  type Message,
} from '../services/messages'
import { PAGINATION } from '../config/constants'
import { normalizeJID } from '../utils/jid'
import type { BareJID } from '../types/jid'
import { messageRepository } from '../services/repositories'
import { outboxRepository } from '../services/repositories/OutboxRepository'
import { useVirtualMessages } from '../contexts/VirtualMessagesContext'
import {
  findDbMatch,
  mergeVirtualAndDb,
  isVirtualMessage,
} from '../utils/message-reconcile'
import type { VirtualMessage } from '../types/ui-message'
import { generateTempId } from '../utils/message'

interface UseMessagesOptions {
  jid: string
  client: Agent | null
  isConnected: boolean
}

export type ChatListItem = Message | VirtualMessage

interface UseMessagesReturn {
  messages: ChatListItem[]
  dbMessages: Message[]
  isLoading: boolean
  isLoadingMore: boolean
  hasMoreMessages: boolean
  error: string | null
  sendMessage: (body: string) => Promise<{ success: boolean; error?: string }>
  loadMoreMessages: () => Promise<void>
  setError: (error: string | null) => void
  virtualSendState: { sent: ReadonlySet<string>; failed: ReadonlySet<string> }
}

export function useMessages({
  jid,
  client,
}: UseMessagesOptions): UseMessagesReturn {
  const [messagesRaw, setMessagesRaw] = useState<Message[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [isLoadingMore, setIsLoadingMore] = useState(false)
  const [hasMoreMessages, setHasMoreMessages] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [sentTempIds, setSentTempIds] = useState<Set<string>>(() => new Set())
  const [failedTempIds, setFailedTempIds] = useState<Set<string>>(() => new Set())

  const isMountedRef = useRef(true)
  const {
    getVirtuals,
    addOutgoingVirtual,
    pruneMatchedVirtuals,
    clearReadingUi,
    clearDeliveredUi,
  } = useVirtualMessages()

  const virtuals = useMemo(
    () => (jid ? getVirtuals(jid) : []),
    [jid, getVirtuals]
  )

  const dbMessages = useMemo(() => {
    if (!client?.jid || !jid) return messagesRaw

    const myBareJid = normalizeJID(client.jid)
    const contactBareJid = normalizeJID(jid)
    const isSelfChat = myBareJid === contactBareJid

    return applySelfChatLogic(messagesRaw, isSelfChat)
  }, [messagesRaw, jid, client?.jid])

  const messages = useMemo(
    () => mergeVirtualAndDb(virtuals, dbMessages),
    [virtuals, dbMessages]
  )

  const reconcileAfterDbChange = useCallback(
    async (updated: Message[]) => {
      if (!jid) return

      const normalizedJid = normalizeJID(jid)
      const convVirtuals = getVirtuals(normalizedJid)
      const matchedIds: string[] = []

      for (const virtual of convVirtuals) {
        let match = findDbMatch(virtual, updated)
        if (!match && virtual.tempId) {
          const outbox = await outboxRepository.getByTempId(virtual.tempId)
          if (outbox?.stanzaId) {
            match = updated.find((m) => m.messageId === outbox.stanzaId)
          }
        }
        if (match) {
          matchedIds.push(virtual.virtualId)
          if (virtual.tempId) {
            await clearOutboxIfSynced(virtual.tempId)
          }
        }
      }

      if (matchedIds.length > 0) {
        pruneMatchedVirtuals(normalizedJid, matchedIds)
      }

      for (const msg of updated) {
        if (!msg.markerFor) continue
        if (msg.markerType === 'displayed') {
          clearReadingUi(msg.markerFor)
        }
        if (msg.markerType === 'receipt') {
          clearDeliveredUi(msg.markerFor)
        }
      }
    },
    [jid, getVirtuals, pruneMatchedVirtuals, clearReadingUi, clearDeliveredUi]
  )

  useEffect(() => {
    isMountedRef.current = true
    return () => {
      isMountedRef.current = false
    }
  }, [])

  const safeSetMessages = useCallback((next: Message[]) => {
    if (isMountedRef.current) {
      setMessagesRaw(next)
    }
  }, [])

  const loadFromCache = useCallback(async () => {
    if (!jid) return

    setIsLoading(true)
    setError(null)

    try {
      const normalizedJid: BareJID = normalizeJID(jid)
      const cached = await messageRepository.getForConversation(normalizedJid, {
        limit: PAGINATION.DEFAULT_MESSAGE_LIMIT,
      })

      if (isMountedRef.current) {
        safeSetMessages(cached)
        setHasMoreMessages(cached.length >= PAGINATION.DEFAULT_MESSAGE_LIMIT)
        await reconcileAfterDbChange(cached)
      }
    } catch (err) {
      console.error('Errore caricamento messaggi da cache:', err)
      if (isMountedRef.current) {
        setError('Impossibile caricare i messaggi')
      }
    } finally {
      if (isMountedRef.current) {
        setIsLoading(false)
      }
    }
  }, [jid, safeSetMessages, reconcileAfterDbChange])

  useEffect(() => {
    if (jid) {
      loadFromCache()
    }
  }, [jid, loadFromCache])

  useEffect(() => {
    if (!jid) return

    const normalizedJid: BareJID = normalizeJID(jid)

    const handleDatabaseChange = async () => {
      if (!isMountedRef.current) return

      try {
        const updated = await messageRepository.getForConversation(normalizedJid)

        if (isMountedRef.current) {
          safeSetMessages(updated)
          await reconcileAfterDbChange(updated)
        }
      } catch (err) {
        console.error('Errore nel ricaricamento messaggi dopo cambio DB:', err)
      }
    }

    const unsubscribe = messageRepository.observe(normalizedJid, handleDatabaseChange)
    return unsubscribe
  }, [jid, safeSetMessages, reconcileAfterDbChange])

  const loadMoreMessages = useCallback(async () => {
    if (isLoadingMore || !hasMoreMessages || messagesRaw.length === 0) return
    if (!isMountedRef.current) return

    setIsLoadingMore(true)

    try {
      const normalizedJid: BareJID = normalizeJID(jid)
      const oldestMessage = messagesRaw[0]

      const olderMessages = await messageRepository.getForConversation(normalizedJid, {
        before: oldestMessage.timestamp,
        limit: PAGINATION.DEFAULT_MESSAGE_LIMIT,
      })

      if (!isMountedRef.current) return

      if (olderMessages.length > 0) {
        safeSetMessages([...olderMessages, ...messagesRaw])
        setHasMoreMessages(olderMessages.length >= PAGINATION.DEFAULT_MESSAGE_LIMIT)
      } else {
        setHasMoreMessages(false)
      }
    } catch (err) {
      console.error('Errore nel caricamento messaggi precedenti:', err)
    } finally {
      if (isMountedRef.current) {
        setIsLoadingMore(false)
      }
    }
  }, [jid, isLoadingMore, hasMoreMessages, messagesRaw, safeSetMessages])

  const sendMessage = useCallback(
    async (body: string): Promise<{ success: boolean; error?: string }> => {
      if (!body.trim()) {
        return { success: false, error: 'Messaggio vuoto' }
      }

      setError(null)
      const tempId = generateTempId()
      addOutgoingVirtual(jid, body, tempId)

      try {
        const result = await sendMessageService(client, jid, body, tempId)

        if (!isMountedRef.current) return { success: false }

        if (result.success) {
          setSentTempIds((prev) => new Set(prev).add(tempId))
        } else {
          setFailedTempIds((prev) => new Set(prev).add(tempId))
          setError(result.error || 'Invio fallito')
        }

        return { success: result.success, error: result.error }
      } catch (err) {
        console.error("Errore nell'invio:", err)
        const errorMsg =
          err instanceof Error ? err.message : "Errore nell'invio del messaggio"
        setFailedTempIds((prev) => new Set(prev).add(tempId))
        if (isMountedRef.current) {
          setError(errorMsg)
        }
        return { success: false, error: errorMsg }
      }
    },
    [client, jid, addOutgoingVirtual]
  )

  const virtualSendState = useMemo(
    () => ({ sent: sentTempIds, failed: failedTempIds }),
    [sentTempIds, failedTempIds]
  )

  return {
    messages,
    dbMessages,
    isLoading,
    isLoadingMore,
    hasMoreMessages,
    error,
    sendMessage,
    loadMoreMessages,
    setError,
    virtualSendState,
  }
}

export { isVirtualMessage }
