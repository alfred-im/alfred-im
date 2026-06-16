/* eslint-disable react-refresh/only-export-components */
import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useState,
  type ReactNode,
} from 'react'
import type { VirtualMessage } from '../types/ui-message'
import { normalizeJID } from '../utils/jid'
import type { BareJID } from '../types/jid'
import { generateTempId } from '../utils/message'

interface VirtualMessagesContextValue {
  getVirtuals: (conversationJid: string) => VirtualMessage[]
  addOutgoingVirtual: (
    conversationJid: string,
    body: string,
    tempId?: string
  ) => string
  addIncomingVirtual: (
    conversationJid: string,
    body: string,
    timestamp?: Date
  ) => string
  removeVirtual: (conversationJid: string, virtualId: string) => void
  pruneMatchedVirtuals: (conversationJid: string, virtualIds: string[]) => void
  readingUi: ReadonlySet<string>
  setReadingUi: (messageId: string) => void
  clearReadingUi: (messageId: string) => void
}

const VirtualMessagesContext = createContext<VirtualMessagesContextValue | undefined>(
  undefined
)

export function VirtualMessagesProvider({ children }: { children: ReactNode }) {
  const [byConversation, setByConversation] = useState<Map<string, VirtualMessage[]>>(
    () => new Map()
  )
  const [readingUi, setReadingUiSet] = useState<Set<string>>(() => new Set())

  const getVirtuals = useCallback(
    (conversationJid: string) => {
      const jid = normalizeJID(conversationJid)
      return byConversation.get(jid) ?? []
    },
    [byConversation]
  )

  const addVirtual = useCallback(
    (
      conversationJid: string,
      entry: Omit<VirtualMessage, 'virtualId' | 'conversationJid'>
    ) => {
      const jid = normalizeJID(conversationJid) as BareJID
      const virtualId = `virt_${generateTempId()}`
      const message: VirtualMessage = {
        virtualId,
        conversationJid: jid,
        ...entry,
      }
      setByConversation((prev) => {
        const next = new Map(prev)
        const list = next.get(jid) ?? []
        next.set(jid, [...list, message])
        return next
      })
      return virtualId
    },
    []
  )

  const addOutgoingVirtual = useCallback(
    (conversationJid: string, body: string, tempId?: string) => {
      return addVirtual(conversationJid, {
        body,
        timestamp: new Date(),
        from: 'me',
        tempId,
        kind: 'outgoing',
      })
    },
    [addVirtual]
  )

  const addIncomingVirtual = useCallback(
    (conversationJid: string, body: string, timestamp = new Date()) => {
      return addVirtual(conversationJid, {
        body,
        timestamp,
        from: 'them',
        kind: 'incoming',
      })
    },
    [addVirtual]
  )

  const removeVirtual = useCallback((conversationJid: string, virtualId: string) => {
    const jid = normalizeJID(conversationJid)
    setByConversation((prev) => {
      const next = new Map(prev)
      const list = next.get(jid) ?? []
      next.set(
        jid,
        list.filter((m) => m.virtualId !== virtualId)
      )
      return next
    })
  }, [])

  const pruneMatchedVirtuals = useCallback(
    (conversationJid: string, virtualIds: string[]) => {
      if (virtualIds.length === 0) return
      const jid = normalizeJID(conversationJid)
      const drop = new Set(virtualIds)
      setByConversation((prev) => {
        const next = new Map(prev)
        const list = next.get(jid) ?? []
        next.set(jid, list.filter((m) => !drop.has(m.virtualId)))
        return next
      })
    },
    []
  )

  const setReadingUi = useCallback((messageId: string) => {
    setReadingUiSet((prev) => new Set(prev).add(messageId))
  }, [])

  const clearReadingUi = useCallback((messageId: string) => {
    setReadingUiSet((prev) => {
      const next = new Set(prev)
      next.delete(messageId)
      return next
    })
  }, [])

  const value = useMemo(
    () => ({
      getVirtuals,
      addOutgoingVirtual,
      addIncomingVirtual,
      removeVirtual,
      pruneMatchedVirtuals,
      readingUi,
      setReadingUi,
      clearReadingUi,
    }),
    [
      getVirtuals,
      addOutgoingVirtual,
      addIncomingVirtual,
      removeVirtual,
      pruneMatchedVirtuals,
      readingUi,
      setReadingUi,
      clearReadingUi,
    ]
  )

  return (
    <VirtualMessagesContext.Provider value={value}>
      {children}
    </VirtualMessagesContext.Provider>
  )
}

export function useVirtualMessages() {
  const ctx = useContext(VirtualMessagesContext)
  if (!ctx) {
    throw new Error('useVirtualMessages deve essere usato dentro VirtualMessagesProvider')
  }
  return ctx
}
