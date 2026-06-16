import type { Agent } from 'stanza'
import type { MAMResult } from 'stanza/protocol'
import { type Conversation } from './conversations-db'
import { normalizeJID, type BareJID } from '../utils/jid'
import { PAGINATION } from '../config/constants'
import { messageRepository } from './repositories'

// Re-export per comodità
export type { Conversation } from './conversations-db'
export { getConversations } from './conversations-db'

/**
 * Estrae il JID del contatto da un messaggio MAM
 * Ritorna un BareJID validato
 */
function extractContactJid(msg: MAMResult, myJid: string): BareJID {
  const myBareJid = normalizeJID(myJid)
  const from = msg.item.message?.from || ''
  const to = msg.item.message?.to || ''

  // Se il messaggio è da me, il contatto è il destinatario
  if (from.startsWith(myBareJid)) {
    return normalizeJID(to)
  }
  // Se il messaggio è a me, il contatto è il mittente
  return normalizeJID(from)
}

/**
 * Estrae il corpo del messaggio
 */
function extractMessageBody(msg: MAMResult): string {
  return msg.item.message?.body || ''
}

/**
 * Estrae il timestamp del messaggio
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

  // 3. Prova con stamp string (formato alternativo)
  const delay = msg.item.message?.delay
  if (delay && typeof delay === 'object' && 'stamp' in delay) {
    const stamp = (delay as { stamp?: string }).stamp
    if (stamp) {
      return new Date(stamp)
    }
  }
  
  // 4. Fallback: timestamp attuale (per messaggi senza delay)
  return new Date()
}

/**
 * Raggruppa messaggi per contatto e estrae l'ultimo messaggio per ogni contatto
 */
function groupMessagesByContact(messages: MAMResult[], myJid: string): Map<string, MAMResult> {
  const groups = new Map<string, MAMResult[]>()

  // Filtra solo messaggi di tipo chat (non groupchat) e con body
  const chatMessages = messages.filter((msg) => {
    const type = msg.item.message?.type
    const body = msg.item.message?.body
    return (!type || type === 'chat') && body && body.trim().length > 0
  })

// Raggruppa per contatto
for (const msg of chatMessages) {
  try {
    const contactJid = extractContactJid(msg, myJid)
    if (!contactJid || contactJid.trim().length === 0) {
      console.warn('⚠️ Messaggio con JID vuoto o non valido, skip:', msg.item.message?.from, msg.item.message?.to)
      continue // Skip messaggi senza contatto valido
    }

    if (!groups.has(contactJid)) {
      groups.set(contactJid, [])
    }
    groups.get(contactJid)!.push(msg)
  } catch (error) {
    console.warn('⚠️ Errore nel processare messaggio MAM, skip:', error, msg)
    continue // Skip messaggi che causano errori
  }
}

  // Per ogni gruppo, prendi il messaggio più recente
  const lastMessages = new Map<string, MAMResult>()
  for (const [contactJid, msgs] of groups.entries()) {
    // Ordina per timestamp (più recente prima)
    const sorted = msgs.sort((a, b) => {
      const timeA = extractTimestamp(a).getTime()
      const timeB = extractTimestamp(b).getTime()
      return timeB - timeA
    })
    lastMessages.set(contactJid, sorted[0])
  }

  return lastMessages
}


/**
 * Carica conversazioni dal server usando MAM
 */
/**
 * Carica conversazioni dal server usando MAM (Message Archive Management)
 * 
 * @param client - Il client XMPP connesso
 * @param options - Opzioni di query
 * @param options.startDate - Data di inizio per il range di ricerca
 * @param options.endDate - Data di fine per il range di ricerca
 * @param options.maxResults - Numero massimo di risultati per pagina
 * @param options.afterToken - Token RSM per paginazione
 * @param options.saveMessages - Se true, salva TUTTI i messaggi nel database (default: false)
 * @returns Promise con le conversazioni trovate, token per paginazione e flag di completezza
 */
export async function loadConversationsFromServer(
  client: Agent,
  options: {
    startDate?: Date
    endDate?: Date
    maxResults?: number
    afterToken?: string
    saveMessages?: boolean
  } = {}
): Promise<{ conversations: Conversation[]; nextToken?: string; complete: boolean }> {
  const { startDate, endDate, maxResults = PAGINATION.DEFAULT_CONVERSATION_LIMIT, afterToken, saveMessages = false } = options

  // Query MAM
  const result = await client.searchHistory({
    start: startDate,
    end: endDate,
    paging: {
      max: maxResults,
      after: afterToken,
    },
  })

  if (!result.results || result.results.length === 0) {
    return {
      conversations: [],
      nextToken: result.paging?.last,
      complete: result.complete ?? true,
    }
  }

  // Se richiesto, salva TUTTI i messaggi nel database
  if (saveMessages) {
    const myJid = client.jid || ''
    const myBareJid = normalizeJID(myJid)
    
    // Converti MAMResult[] in Message[]
    const messages = result.results
      .filter(msg => msg.item.message?.body) // Solo messaggi con body
      .map(msg => {
        const from = msg.item.message?.from || ''
        const contactJid = extractContactJid(msg, myJid)
        
        return {
          messageId: msg.id || `mam_${Date.now()}_${Math.random()}`,
          conversationJid: contactJid,
          body: extractMessageBody(msg),
          timestamp: extractTimestamp(msg),
          from: from.startsWith(myBareJid) ? 'me' as const : 'them' as const,
          status: 'sent' as const,
        }
      })
    
    // Salva tutti i messaggi nel database
    if (messages.length > 0) {
      await messageRepository.saveAll(messages)
    }
  }

  // Raggruppa per contatto
  const lastMessages = groupMessagesByContact(result.results, client.jid || '')

  // Converti in conversazioni
  const conversations: Conversation[] = []
  for (const [contactJid, msg] of lastMessages.entries()) {
    // TypeScript: contactJid è BareJID dalla Map
    const jid: BareJID = contactJid as BareJID
    
    // Correggo extractSender per usare myJid corretto
    const myBareJid = normalizeJID(client.jid || '')
    const from = msg.item.message?.from || ''
    const sender: 'me' | 'them' = from.startsWith(myBareJid) ? 'me' : 'them'

    const messageTimestamp = extractTimestamp(msg)
    conversations.push({
      jid,
      lastMessage: {
        body: extractMessageBody(msg),
        timestamp: messageTimestamp,
        from: sender,
        messageId: msg.id,
      },
      unreadCount: 0,
      updatedAt: messageTimestamp,
    })
  }

  // Ordina per timestamp (più recenti prima)
  conversations.sort(
    (a, b) => b.lastMessage.timestamp.getTime() - a.lastMessage.timestamp.getTime()
  )

  return {
    conversations,
    nextToken: result.paging?.last,
    complete: result.complete ?? true,
  }
}

/**
 * Scarica TUTTE le conversazioni dal server
 * @param client - Client XMPP connesso
 * @param saveMessages - Se true, salva TUTTI i messaggi nel database durante lo scaricamento (default: false)
 * @returns Conversazioni scaricate e ultimo token RSM
 */
export async function downloadAllConversations(
  client: Agent,
  saveMessages = false
): Promise<{ conversations: Conversation[]; lastToken?: string }> {
  let allConversations: Conversation[] = []
  let hasMore = true
  let lastToken: string | undefined

  // Carica tutte le pagine fino a quando non ci sono più risultati
  while (hasMore) {
    const result = await loadConversationsFromServer(client, {
      maxResults: PAGINATION.DEFAULT_CONVERSATION_LIMIT,
      afterToken: lastToken,
      saveMessages, // Passa il parametro saveMessages
    })

    // Raggruppa e aggiungi alle conversazioni totali
    allConversations = [...allConversations, ...result.conversations]

    // Controlla se ci sono altre pagine
    hasMore = !result.complete && !!result.nextToken
    lastToken = result.nextToken
  }

  // Ordina tutte le conversazioni per timestamp (più recenti prima)
  allConversations.sort(
    (a, b) => b.lastMessage.timestamp.getTime() - a.lastMessage.timestamp.getTime()
  )

  // Rimuovi duplicati (se ci sono) mantenendo quella con timestamp più recente
  const conversationMap = new Map<string, Conversation>()
  for (const conv of allConversations) {
    const existing = conversationMap.get(conv.jid)
    if (!existing || conv.lastMessage.timestamp.getTime() > existing.lastMessage.timestamp.getTime()) {
      conversationMap.set(conv.jid, conv)
    }
  }

  const uniqueConversations = Array.from(conversationMap.values())

  return {
    conversations: uniqueConversations,
    lastToken,
  }
}

/**
 * Arricchisce conversazioni con dati dal roster (nomi contatti) e vCard (avatar e nomi pubblici)
 * 
 * @param client - Client XMPP
 * @param conversations - Lista conversazioni da arricchire
 * @param forceRefreshVCards - Se true, ricarica i vCard dal server ignorando la cache
 */
export async function enrichWithRoster(
  client: Agent,
  conversations: Conversation[],
  forceRefreshVCards = false
): Promise<Conversation[]> {
  try {
    // 1. Recupera roster (nomi personalizzati dall'utente)
    const rosterResult = await client.getRoster()
    const rosterData = rosterResult as unknown as { roster?: { items?: Array<{ jid: string; name?: string }> } }
    const rosterItems = rosterData.roster?.items || []
    const rosterMap = new Map(
      rosterItems.map((item) => [normalizeJID(item.jid), item])
    )

    // 2. Recupera vCard per tutti i contatti (in batch)
    const { getVCardsForJids, getDisplayName } = await import('./vcard')
    const jids = conversations.map(conv => conv.jid)
    const vcardMap = await getVCardsForJids(client, jids, forceRefreshVCards)

    // 3. Arricchisci le conversazioni con roster e vCard
    return conversations.map((conv) => {
      const rosterItem = rosterMap.get(conv.jid)
      const vcard = vcardMap.get(conv.jid)

      // Determina il nome da visualizzare (priorità: roster > vCard fullName > vCard nickname > JID)
      const displayName = getDisplayName(conv.jid, rosterItem?.name, vcard)

      return {
        ...conv,
        displayName,
        avatarData: vcard?.photoData,
        avatarType: vcard?.photoType,
      }
    })
  } catch (error) {
    console.error('Errore nel recupero roster/vCard:', error)
    return conversations
  }
}
