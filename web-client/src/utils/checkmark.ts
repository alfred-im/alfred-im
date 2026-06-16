import type { Message } from '../services/conversations-db'
import type { CheckmarkLevel } from '../types/message-states'

function findAcksFor(messageId: string, allMessages: Message[]) {
  return allMessages.filter((m) => m.markerFor === messageId && m.markerType)
}

/**
 * Risolve il livello spunta UI (modello WhatsApp a 3 livelli).
 * Priorità: reading > delivered > sent
 */
export function resolveCheckmarkLevel(
  message: Message,
  allMessages: Message[],
  overlays: { reading: ReadonlySet<string>; delivered: ReadonlySet<string> }
): CheckmarkLevel {
  if (message.from !== 'me') {
    return 'sent'
  }

  if (message.status === 'pending') return 'pending'
  if (message.status === 'failed') return 'failed'

  const acks = findAcksFor(message.messageId, allMessages)
  const hasDisplayed = acks.some((m) => m.markerType === 'displayed')
  const hasReceipt = acks.some((m) => m.markerType === 'receipt')

  if (hasDisplayed || overlays.reading.has(message.messageId)) {
    return 'reading'
  }
  if (hasReceipt || overlays.delivered.has(message.messageId)) {
    return 'delivered'
  }

  return 'sent'
}
