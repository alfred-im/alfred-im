import type { Agent } from 'stanza'
import { outboxRepository } from './repositories/OutboxRepository'
import { scheduleConversationMamSync } from './mam-sync'
import { normalizeJID } from '../utils/jid'
import { generateTempId } from '../utils/message'

/**
 * Accoda messaggio in outbox (persistito) e tenta invio XMPP.
 * NON scrive nel DB messaggi — solo MAM dopo invio.
 */
export async function sendMessage(
  client: Agent | null,
  toJid: string,
  body: string,
  existingTempId?: string
): Promise<{ tempId: string; success: boolean; error?: string }> {
  const tempId = existingTempId ?? generateTempId()
  const normalizedJid = normalizeJID(toJid)
  const timestamp = new Date()

  await outboxRepository.save({
    tempId,
    conversationJid: normalizedJid,
    body,
    timestamp,
    status: 'queued',
  })

  if (!client) {
    return { tempId, success: false, error: 'Non connesso' }
  }

  return transmitOutboxEntry(client, tempId)
}

export async function transmitOutboxEntry(
  client: Agent,
  tempId: string
): Promise<{ tempId: string; success: boolean; error?: string }> {
  const entry = await outboxRepository.getByTempId(tempId)
  if (!entry) {
    return { tempId, success: false, error: 'Messaggio non trovato in outbox' }
  }

  await outboxRepository.updateStatus(tempId, 'sending')

  try {
    const messageId = await client.sendMessage({
      to: entry.conversationJid,
      body: entry.body,
      type: 'chat',
      marker: { type: 'markable' },
      receipt: { type: 'request' },
    })

    const stanzaId = typeof messageId === 'string' ? messageId : tempId
    await outboxRepository.updateStatus(tempId, 'queued', { stanzaId })

    scheduleConversationMamSync(client, entry.conversationJid, 'send')

    console.log('✅ Messaggio inviato (outbox), MAM schedulato:', stanzaId)
    return { tempId, success: true }
  } catch (error) {
    const msg = error instanceof Error ? error.message : 'Errore sconosciuto'
    await outboxRepository.updateStatus(tempId, 'failed', { lastError: msg })
    console.error('❌ Errore invio messaggio:', error)
    return { tempId, success: false, error: msg }
  }
}

/** Invia tutti i messaggi in coda dopo riconnessione */
export async function flushOutbox(client: Agent): Promise<void> {
  const pending = await outboxRepository.getQueued()
  for (const entry of pending) {
    await transmitOutboxEntry(client, entry.tempId)
  }
}

/**
 * Dopo sync MAM: rimuovi outbox se il messaggio è nel DB
 */
export async function clearOutboxIfSynced(tempId: string): Promise<void> {
  await outboxRepository.delete(tempId)
}
