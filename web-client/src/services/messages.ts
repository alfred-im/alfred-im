import type { Agent } from 'stanza'
import type { MAMResult } from 'stanza/protocol'
import {
  getMessagesForConversation,
  type Message,
} from './conversations-db'
import { normalizeJID } from '../utils/jid'
import type { BareJID } from '../types/jid'
import { PAGINATION } from '../config/constants'
import { messageRepository } from './repositories'
import { extractCanonicalMessageIdFromMam } from '../utils/message-id'

// Re-export per comodità
export type { Message, MessageStatus } from './conversations-db'

/**
 * Estrae timestamp da un messaggio MAM
 * Il timestamp è già un oggetto Date fornito dalla libreria stanza
 */
function extractTimestamp(msg: MAMResult): Date {
  // 1. Prova con il delay del wrapper Forward (MAM standard)
  if (msg.item?.delay?.timestamp) {
    return msg.item.delay.timestamp
  }

  // 2. Prova con il delay del messaggio interno (per messaggi offline)
  if (msg.item?.message?.delay?.timestamp) {
    return msg.item.message.delay.timestamp
  }
  
  // 3. Fallback: timestamp attuale (per messaggi senza delay)
  console.warn('Nessun timestamp trovato nel messaggio MAM, uso timestamp corrente', msg)
  return new Date()
}

/**
 * Converte un MAMResult in Message
 * Nota: per self-chat la direzione viene determinata dopo dalla funzione applySelfChatLogic
 */
function mamResultToMessage(msg: MAMResult, conversationJid: string, myJid: string): Message {
  const myBareJid = normalizeJID(myJid)
  const inner = msg.item.message
  const from = inner?.from || ''
  const fromMe = from.startsWith(myBareJid)
  const mamArchiveId = msg.id
  const timestamp = extractTimestamp(msg)
  const normalizedContactJid = normalizeJID(conversationJid)

  // Marker XEP-0333 v1.0: solo `displayed` (received/acknowledged rimossi dalla spec)
  if (inner?.marker?.type === 'displayed' && inner.marker.id) {
    return {
      messageId: `mam-marker-${mamArchiveId ?? Date.now()}`,
      mamArchiveId,
      conversationJid: normalizedContactJid,
      body: '',
      timestamp,
      from: fromMe ? 'me' : 'them',
      status: 'sent',
      markerType: 'displayed',
      markerFor: inner.marker.id,
    }
  }

  return {
    messageId: extractCanonicalMessageIdFromMam(msg),
    mamArchiveId,
    conversationJid: normalizedContactJid,
    body: inner?.body || '',
    timestamp,
    from: fromMe ? 'me' : 'them',
    status: 'sent',
  }
}

/**
 * Applica la logica di alternanza per messaggi self-chat
 * In self-chat ogni messaggio appare DUE volte nell'archivio MAM:
 * - Prima occorrenza = messaggio inviato ('me')
 * - Seconda occorrenza = messaggio ricevuto ('them')
 * 
 * Identifica i duplicati basandosi su body + timestamp simile
 * DEVE essere applicata sull'array completo e ordinato, non su singoli batch
 */
export function applySelfChatLogic(messages: Message[], isSelfChat: boolean): Message[] {
  if (!isSelfChat || messages.length === 0) {
    return messages
  }

  // Mappa per tracciare messaggi già visti: chiave = body+timestamp (arrotondato al secondo)
  const seenMessages = new Map<string, number>()
  
  return messages.map((msg) => {
    // Crea chiave univoca basata su body + timestamp (arrotondato al secondo)
    const timestampKey = Math.floor(msg.timestamp.getTime() / 1000)
    const key = `${msg.body}:${timestampKey}`
    
    const occurrenceCount = seenMessages.get(key) || 0
    seenMessages.set(key, occurrenceCount + 1)
    
    // Prima occorrenza = sent ('me'), seconda occorrenza = received ('them')
    return {
      ...msg,
      from: occurrenceCount === 0 ? 'me' : 'them',
    }
  })
}

/**
 * Carica messaggi per un contatto specifico dal server usando MAM (Message Archive Management)
 * Con supporto per paginazione usando RSM (Result Set Management) tokens
 * 
 * @param client - Il client XMPP connesso
 * @param contactJid - Il JID del contatto per cui caricare i messaggi
 * @param options - Opzioni di paginazione
 * @param options.maxResults - Numero massimo di messaggi da caricare (default: 50)
 * @param options.afterToken - Token RSM per caricare messaggi DOPO questo punto (più recenti)
 * @param options.beforeToken - Token RSM per caricare messaggi PRIMA di questo punto (più vecchi)
 * @returns Promise con i messaggi caricati, token RSM e flag di completezza
 * 
 * @example
 * ```ts
 * // Carica i primi 50 messaggi
 * const result = await loadMessagesForContact(client, 'user@example.com')
 * 
 * // Carica messaggi più vecchi usando il token
 * const older = await loadMessagesForContact(client, 'user@example.com', {
 *   beforeToken: result.firstToken
 * })
 * ```
 */
export async function loadMessagesForContact(
  client: Agent,
  contactJid: string,
  options?: {
    maxResults?: number
    afterToken?: string  // Token per caricare messaggi DOPO questo punto (più recenti)
    beforeToken?: string // Token per caricare messaggi PRIMA di questo punto (più vecchi)
    endBefore?: Date     // Sync boundary T: MAM scarica solo messaggi prima di questo momento
    startAfter?: Date    // Watermark listener: MAM non riscarica messaggi già coperti dal listener
  }
): Promise<{ 
  messages: Message[]
  firstToken?: string  // Token del primo messaggio (per paginare indietro)
  lastToken?: string   // Token dell'ultimo messaggio (per paginare avanti)
  complete: boolean 
}> {
  const { maxResults = PAGINATION.DEFAULT_MESSAGE_LIMIT, afterToken, beforeToken, endBefore, startAfter } = options || {}

  try {
    const normalizedContactJid = normalizeJID(contactJid)
    if (!normalizedContactJid || normalizedContactJid.trim().length === 0) {
      throw new Error('JID contatto non valido')
    }

    // Query MAM filtrata per contatto specifico (end = boundary T del handoff sync/listener)
    const result = await client.searchHistory({
      with: normalizedContactJid,
      start: startAfter,
      end: endBefore,
      paging: {
        max: maxResults,
        after: afterToken,
        before: beforeToken,
      },
    })

    if (!result.results || result.results.length === 0) {
      return {
        messages: [],
        firstToken: result.paging?.first,
        lastToken: result.paging?.last,
        complete: result.complete ?? true,
      }
    }

    // Converti TUTTI i messaggi MAMResult in Message (inclusi ping, token, visualizzazioni, ecc.)
    const myJid = client.jid || ''

    const allMessages = result.results
      .map((msg) => {
        try {
          return mamResultToMessage(msg, contactJid, myJid)
        } catch (error) {
          console.warn('⚠️ Errore nel convertire messaggio MAM, skip:', error)
          return null
        }
      })
      .filter((msg): msg is Message => msg !== null)

    // Salva TUTTI i messaggi nel database (dati raw, senza alternanza self-chat)
    if (allMessages.length > 0) {
      await messageRepository.saveAll(allMessages)
    }

    // Filtra solo messaggi di chat validi (con body) per la visualizzazione nella UI
    const validMessages = allMessages.filter(msg => msg.body && msg.body.trim().length > 0)

    // NON applicare alternanza qui - sarà applicata nella UI sull'array completo
    return {
      messages: validMessages,
      firstToken: result.paging?.first,  // Token per paginare verso messaggi più vecchi
      lastToken: result.paging?.last,    // Token per paginare verso messaggi più recenti
      complete: result.complete ?? true,
    }
  } catch (error) {
    console.error('Errore nel caricamento messaggi MAM:', error)
    throw new Error('Impossibile caricare i messaggi dal server')
  }
}

/**
 * Carica tutti i messaggi disponibili per un contatto
 * (utile per prima apertura della chat)
 */
export async function loadAllMessagesForContact(
  client: Agent,
  contactJid: string
): Promise<Message[]> {
  const allMessages: Message[] = []
  let hasMore = true
  let afterToken: string | undefined

  while (hasMore) {
    const result = await loadMessagesForContact(client, contactJid, {
      maxResults: PAGINATION.DEFAULT_CONVERSATION_LIMIT,
      afterToken,
    })

    allMessages.push(...result.messages)

    hasMore = !result.complete && !!result.lastToken
    afterToken = result.lastToken
  }

  return allMessages
}

/**
 * Scarica tutti i messaggi dal server senza salvarli nel DB
 * Utile per refresh completo dove si vuole scaricare prima, poi svuotare e salvare
 */
export async function downloadAllMessagesFromServer(
  client: Agent,
  contactJid: string
): Promise<Message[]> {
  const normalizedJid = normalizeJID(contactJid)
  const messagesMap = new Map<string, Message>() // Usa Map per de-duplicazione automatica
  let hasMore = true
  let afterToken: string | undefined
  const myJid = client.jid || ''

  while (hasMore) {
    try {
      // Query MAM senza salvare nel DB
      const result = await client.searchHistory({
        with: normalizedJid,
        paging: {
          max: PAGINATION.DEFAULT_CONVERSATION_LIMIT,
          after: afterToken,
        },
      })

      if (!result.results || result.results.length === 0) {
        break
      }

      // Converti TUTTI i messaggi in Message (inclusi ping, token, visualizzazioni, ecc.)
      // NON filtrare qui - salviamo tutto nel database
      const messages = result.results.map((msg) =>
        mamResultToMessage(msg, contactJid, myJid)
      )
      
      // Aggiungi alla Map per de-duplicazione automatica per messageId
      messages.forEach(msg => messagesMap.set(msg.messageId, msg))

      hasMore = !result.complete && !!result.paging?.last
      afterToken = result.paging?.last
    } catch (error) {
      console.error('Errore nel caricamento batch messaggi:', error)
      break
    }
  }

  // Converti Map in array ordinato per timestamp
  const allMessages = Array.from(messagesMap.values()).sort(
    (a, b) => a.timestamp.getTime() - b.timestamp.getTime()
  )

  // NON applicare alternanza qui - sarà applicata nella UI sull'array completo
  return allMessages
}

export {
  sendMessage,
  transmitOutboxEntry,
  flushOutbox,
  clearOutboxIfSynced,
} from './outbox-send'

import { sendMessage as sendMessageOutbox } from './outbox-send'

/**
 * Riprova a inviare un messaggio fallito
 * Semplificato: solo re-invio senza sync
 */
export async function retryMessage(
  client: Agent,
  message: Message
): Promise<{ success: boolean; error?: string }> {
  if (message.status !== 'failed') {
    return { success: false, error: 'Il messaggio non è in stato failed' }
  }

  try {
    // Re-invia il messaggio
    const result = await sendMessageOutbox(client, message.conversationJid, message.body, message.tempId)
    return { success: result.success, error: result.error }
  } catch (error) {
    console.error('Errore nel retry del messaggio:', error)
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Errore sconosciuto',
    }
  }
}

/**
 * Carica messaggi dal database locale (più veloce, per UI)
 * Filtra automaticamente messaggi vuoti (senza body)
 */
export async function getLocalMessages(
  conversationJid: BareJID,
  options?: {
    limit?: number
    before?: Date
  }
): Promise<Message[]> {
  const messages = await getMessagesForConversation(conversationJid, options)
  // Filtra messaggi vuoti (senza body) - possono essere ping, visualizzazioni, ecc.
  return messages.filter(msg => msg.body && msg.body.trim().length > 0)
}
