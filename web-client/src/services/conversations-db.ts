import { openDB } from 'idb'
import type { DBSchema, IDBPDatabase } from 'idb'
import { type BareJID } from '../types/jid'
import type { OutboxEntry } from '../types/outbox'

export type { OutboxEntry } from '../types/outbox'

export interface Conversation {
  jid: BareJID
  displayName?: string
  avatarData?: string // Base64 image data
  avatarType?: string // MIME type (es: 'image/png')
  lastMessage: {
    body: string
    timestamp: Date
    from: 'me' | 'them'
    messageId: string
  }
  unreadCount: number
  updatedAt: Date
}

export type MessageStatus = 'pending' | 'sent' | 'delivered' | 'failed'

export interface Message {
  messageId: string // ID dal server o ID temporaneo
  conversationJid: BareJID // JID bare del contatto (validato)
  body: string
  timestamp: Date
  from: 'me' | 'them'
  status: MessageStatus
  tempId?: string // ID temporaneo per optimistic updates (prima della conferma server)
  /** UID archivio MAM (per migrazione da vecchi record e paginazione) */
  mamArchiveId?: string
  
  // XEP-0333 Chat Markers
  markerType?: 'displayed'
  markerFor?: string // messageId del messaggio referenziato
}

export interface VCardCache {
  jid: BareJID
  fullName?: string
  nickname?: string
  photoData?: string // Base64 image data
  photoType?: string // MIME type
  email?: string
  description?: string
  lastUpdated: Date
}

interface ConversationsDB extends DBSchema {
  conversations: {
    key: string // jid
    value: Conversation
    indexes: { 'by-updatedAt': Date }
  }
  messages: {
    key: string // messageId
    value: Message
    indexes: { 
      'by-conversationJid': string
      'by-timestamp': Date
      'by-conversation-timestamp': [string, Date] // Compound index per query efficienti
      'by-tempId': string // Index per lookup veloce di messaggi temporanei
    }
  }
  vcards: {
    key: string // jid
    value: VCardCache
    indexes: { 'by-lastUpdated': Date }
  }
  metadata: {
    key: string
    value: {
      lastSync: Date
      lastRSMToken?: string
      conversationTokens?: Record<string, string>
      listenerCoveredUntil?: Record<string, string>
    }
  }
  outbox: {
    key: string
    value: OutboxEntry
    indexes: { 'by-conversationJid': string; 'by-status': string }
  }
}

let dbInstance: IDBPDatabase<ConversationsDB> | null = null

export async function getDB(): Promise<IDBPDatabase<ConversationsDB>> {
  if (dbInstance) {
    return dbInstance
  }

  dbInstance = await openDB<ConversationsDB>('conversations-db', 4, {
    upgrade(db, oldVersion) {
      // Versione 1: Store originali
      if (oldVersion < 1) {
        // Store per conversazioni
        const conversationStore = db.createObjectStore('conversations', {
          keyPath: 'jid',
        })
        conversationStore.createIndex('by-updatedAt', 'updatedAt')

        // Store per metadata
        db.createObjectStore('metadata')
      }

      // Versione 2: Aggiungi store messaggi
      if (oldVersion < 2) {
        const messagesStore = db.createObjectStore('messages', {
          keyPath: 'messageId',
        })
        messagesStore.createIndex('by-conversationJid', 'conversationJid')
        messagesStore.createIndex('by-timestamp', 'timestamp')
        messagesStore.createIndex('by-conversation-timestamp', ['conversationJid', 'timestamp'])
        messagesStore.createIndex('by-tempId', 'tempId', { unique: false })
      }

      // Versione 3: Aggiungi store vcard
      if (oldVersion < 3) {
        const vcardStore = db.createObjectStore('vcards', {
          keyPath: 'jid',
        })
        vcardStore.createIndex('by-lastUpdated', 'lastUpdated')
      }

      // Versione 4: Outbox messaggi in uscita (queued / sending / failed)
      if (oldVersion < 4) {
        const outboxStore = db.createObjectStore('outbox', {
          keyPath: 'tempId',
        })
        outboxStore.createIndex('by-conversationJid', 'conversationJid')
        outboxStore.createIndex('by-status', 'status')
      }
    },
  })

  return dbInstance
}

export async function saveConversations(conversations: Conversation[]): Promise<void> {
  const db = await getDB()
  const tx = db.transaction('conversations', 'readwrite')

  for (const conv of conversations) {
    // Merge con conversazione esistente se presente
    const existing = await tx.store.get(conv.jid)
    if (existing) {
      // Mantieni unreadCount se non viene resettato
      conv.unreadCount = existing.unreadCount
    }
    await tx.store.put(conv)
  }

  await tx.done
}

export async function getConversations(): Promise<Conversation[]> {
  const db = await getDB()
  const tx = db.transaction('conversations', 'readonly')
  const conversations = await tx.store.getAll()
  await tx.done

  // Converti le Date che potrebbero essere state serializzate come stringhe
  const conversationsWithDates = conversations.map(conv => ({
    ...conv,
    lastMessage: {
      ...conv.lastMessage,
      timestamp: conv.lastMessage.timestamp instanceof Date 
        ? conv.lastMessage.timestamp 
        : new Date(conv.lastMessage.timestamp)
    },
    updatedAt: conv.updatedAt instanceof Date 
      ? conv.updatedAt 
      : new Date(conv.updatedAt)
  }))

  // Ordina per data ultimo messaggio (più recenti prima)
  return conversationsWithDates.sort(
    (a, b) => b.lastMessage.timestamp.getTime() - a.lastMessage.timestamp.getTime()
  )
}

export async function updateConversation(jid: string, updates: Partial<Conversation>): Promise<void> {
  const db = await getDB()
  const tx = db.transaction('conversations', 'readwrite')
  const existing = await tx.store.get(jid)

  if (existing) {
    // Converti Date se necessario per la conversazione esistente
    const existingTimestamp = existing.lastMessage.timestamp instanceof Date
      ? existing.lastMessage.timestamp
      : new Date(existing.lastMessage.timestamp)
    
    // Converti Date se necessario per gli updates
    const updatesTimestamp = updates.lastMessage?.timestamp
      ? (updates.lastMessage.timestamp instanceof Date
          ? updates.lastMessage.timestamp
          : new Date(updates.lastMessage.timestamp))
      : existingTimestamp
    
    // Se viene aggiornato lastMessage, aggiorna anche updatedAt con il timestamp del messaggio
    const updatedAt = updates.lastMessage?.timestamp ? updatesTimestamp : existingTimestamp
    
    await tx.store.put({ 
      ...existing, 
      ...updates, 
      updatedAt,
      lastMessage: updates.lastMessage 
        ? { ...updates.lastMessage, timestamp: updatesTimestamp }
        : { ...existing.lastMessage, timestamp: existingTimestamp }
    })
  } else if (updates.jid) {
    // Crea nuova conversazione
    const timestamp = updates.lastMessage!.timestamp instanceof Date
      ? updates.lastMessage!.timestamp
      : new Date(updates.lastMessage!.timestamp)
    
    await tx.store.put({
      jid: updates.jid,
      lastMessage: {
        ...updates.lastMessage!,
        timestamp
      },
      unreadCount: updates.unreadCount ?? 0,
      displayName: updates.displayName,
      updatedAt: timestamp,
    })
  }

  await tx.done
}

export async function getMetadata(): Promise<{ lastSync: Date; lastRSMToken?: string } | null> {
  const db = await getDB()
  const tx = db.transaction('metadata', 'readonly')
  const metadata = await tx.store.get('sync')
  await tx.done
  return metadata || null
}

export async function saveMetadata(metadata: { lastSync: Date; lastRSMToken?: string }): Promise<void> {
  const db = await getDB()
  const tx = db.transaction('metadata', 'readwrite')
  await tx.store.put(metadata, 'sync')
  await tx.done
}

export async function removeConversation(jid: string): Promise<void> {
  const db = await getDB()
  const tx = db.transaction('conversations', 'readwrite')
  await tx.store.delete(jid)
  await tx.done
}

export async function removeConversations(jids: string[]): Promise<void> {
  if (jids.length === 0) return
  
  const db = await getDB()
  const tx = db.transaction('conversations', 'readwrite')
  
  for (const jid of jids) {
    await tx.store.delete(jid)
  }
  
  await tx.done
}

export async function clearDatabase(): Promise<void> {
  const db = await getDB()
  const tx = db.transaction(['conversations', 'metadata', 'messages'], 'readwrite')
  await tx.objectStore('conversations').clear()
  await tx.objectStore('metadata').clear()
  await tx.objectStore('messages').clear()
  await tx.done
}

/**
 * Svuota solo le conversazioni dal database (mantiene messaggi e metadata)
 * Utile per refresh completo delle conversazioni dal server
 */
export async function clearConversations(): Promise<void> {
  const db = await getDB()
  const tx = db.transaction('conversations', 'readwrite')
  await tx.objectStore('conversations').clear()
  await tx.done
}

// ============================================================================
// MESSAGES CRUD OPERATIONS
// ============================================================================

/**
 * Aggiunge un singolo messaggio
 */
export async function addMessage(message: Message): Promise<void> {
  const db = await getDB()
  const tx = db.transaction('messages', 'readwrite')
  
  // Verifica se esiste già
  const existing = await tx.store.get(message.messageId)
  if (!existing) {
    // Nuovo messaggio
    await tx.store.put(message)
  } else {
    // Messaggio esiste - aggiorna solo se necessario
    let shouldUpdate = false
    const updated = { ...existing }
    
    // Aggiorna status se migliora
    if (existing.status === 'pending' && message.status === 'sent') {
      updated.status = 'sent'
      shouldUpdate = true
    }
    
    // Aggiorna timestamp se quello nuovo è più accurato
    const now = new Date()
    const existingIsRecent = Math.abs(existing.timestamp.getTime() - now.getTime()) < 5000
    const newIsNotRecent = Math.abs(message.timestamp.getTime() - now.getTime()) > 5000
    if (existingIsRecent && newIsNotRecent) {
      updated.timestamp = message.timestamp
      shouldUpdate = true
    }
    
    if (shouldUpdate) {
      await tx.store.put(updated)
    }
  }
  
  await tx.done
}

/**
 * Recupera messaggi per una conversazione specifica
 * Ordinati per timestamp (più vecchi prima per il rendering)
 */
export async function getMessagesForConversation(
  conversationJid: BareJID,
  options?: {
    limit?: number
    before?: Date // Carica messaggi prima di questa data (per paginazione)
  }
): Promise<Message[]> {
  const db = await getDB()
  const tx = db.transaction('messages', 'readonly')
  const index = tx.store.index('by-conversation-timestamp')

  // Query range
  let range: IDBKeyRange
  if (options?.before) {
    // Messaggi della conversazione con timestamp < before
    range = IDBKeyRange.bound(
      [conversationJid, new Date(0)],
      [conversationJid, options.before],
      false,
      true // exclude upper bound
    )
  } else {
    // Tutti i messaggi della conversazione
    range = IDBKeyRange.bound(
      [conversationJid, new Date(0)],
      [conversationJid, new Date(Date.now() + 86400000)], // +1 giorno per sicurezza
      false,
      false
    )
  }

  let messages = await index.getAll(range)
  await tx.done

  // Ordina per timestamp (più vecchi prima)
  messages.sort((a, b) => a.timestamp.getTime() - b.timestamp.getTime())

  // Applica limit se specificato (prendi gli ultimi N)
  if (options?.limit && messages.length > options.limit) {
    messages = messages.slice(-options.limit)
  }

  return messages
}

/**
 * Conta il numero di messaggi per una conversazione
 */
export async function countMessagesForConversation(conversationJid: BareJID): Promise<number> {
  const db = await getDB()
  const tx = db.transaction('messages', 'readonly')
  const index = tx.store.index('by-conversationJid')
  const count = await index.count(conversationJid)
  await tx.done
  return count
}

/**
 * Aggiorna lo status di un messaggio
 */
export async function updateMessageStatus(
  messageId: string,
  status: MessageStatus
): Promise<void> {
  const db = await getDB()
  const tx = db.transaction('messages', 'readwrite')
  const existing = await tx.store.get(messageId)

  if (existing) {
    await tx.store.put({ ...existing, status })
  }

  await tx.done
}

/**
 * Aggiorna l'ID di un messaggio da temporaneo a server ID
 */
export async function updateMessageId(
  tempId: string,
  newMessageId: string
): Promise<void> {
  const db = await getDB()
  const tx = db.transaction('messages', 'readwrite')

  // Usa index per trovare il messaggio invece di getAll()
  const index = tx.store.index('by-tempId')
  const message = await index.get(tempId)

  if (message) {
    // Rimuovi il vecchio record
    await tx.store.delete(message.messageId)
    
    // Inserisci con nuovo ID
    await tx.store.put({
      ...message,
      messageId: newMessageId,
      tempId: tempId,
      status: 'sent',
    })
  }

  await tx.done
}

/**
 * Trova un messaggio per ID temporaneo
 */
export async function getMessageByTempId(tempId: string): Promise<Message | null> {
  const db = await getDB()
  const tx = db.transaction('messages', 'readonly')
  const index = tx.store.index('by-tempId')
  const message = await index.get(tempId)
  await tx.done

  return message || null
}

/**
 * Elimina un messaggio
 */
export async function deleteMessage(messageId: string): Promise<void> {
  const db = await getDB()
  const tx = db.transaction('messages', 'readwrite')
  await tx.store.delete(messageId)
  await tx.done
}

// ============================================================================
// VCARD CRUD OPERATIONS
// ============================================================================

/**
 * Salva un vCard nella cache locale
 */
export async function saveVCard(vcard: VCardCache): Promise<void> {
  const db = await getDB()
  const tx = db.transaction('vcards', 'readwrite')
  await tx.store.put(vcard)
  await tx.done
}

/**
 * Salva multipli vCard nella cache locale
 */
export async function saveVCards(vcards: VCardCache[]): Promise<void> {
  if (vcards.length === 0) return

  const db = await getDB()
  const tx = db.transaction('vcards', 'readwrite')
  
  for (const vcard of vcards) {
    await tx.store.put(vcard)
  }
  
  await tx.done
}

/**
 * Recupera un vCard dalla cache locale
 */
export async function getVCard(jid: string): Promise<VCardCache | null> {
  const db = await getDB()
  const tx = db.transaction('vcards', 'readonly')
  const vcard = await tx.store.get(jid)
  await tx.done
  
  if (!vcard) return null
  
  // Converti Date se serializzata
  return {
    ...vcard,
    lastUpdated: vcard.lastUpdated instanceof Date 
      ? vcard.lastUpdated 
      : new Date(vcard.lastUpdated)
  }
}

/**
 * Recupera tutti i vCard dalla cache locale
 */
export async function getAllVCards(): Promise<VCardCache[]> {
  const db = await getDB()
  const tx = db.transaction('vcards', 'readonly')
  const vcards = await tx.store.getAll()
  await tx.done
  
  // Converti Date se serializzate
  return vcards.map(vcard => ({
    ...vcard,
    lastUpdated: vcard.lastUpdated instanceof Date 
      ? vcard.lastUpdated 
      : new Date(vcard.lastUpdated)
  }))
}

/**
 * Elimina un vCard dalla cache
 */
export async function deleteVCard(jid: string): Promise<void> {
  const db = await getDB()
  const tx = db.transaction('vcards', 'readwrite')
  await tx.store.delete(jid)
  await tx.done
}

/**
 * Pulisce tutti i vCard dalla cache
 */
export async function clearVCards(): Promise<void> {
  const db = await getDB()
  const tx = db.transaction('vcards', 'readwrite')
  await tx.store.clear()
  await tx.done
}
