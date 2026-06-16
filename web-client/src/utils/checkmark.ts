import type { Message } from '../services/conversations-db'
import type { CheckmarkLevel } from '../types/message-states'

function findMarkersFor(messageId: string, allMessages: Message[]) {
  return allMessages.filter((m) => m.markerFor === messageId && m.markerType)
}

/**
 * Risolve il livello spunta UI per un messaggio inviato da me.
 * XEP-0333 v1.0: solo `displayed` → lettura (✓✓ blu).
 */
export function resolveCheckmarkLevel(
  message: Message,
  allMessages: Message[],
  readingUi: ReadonlySet<string>
): CheckmarkLevel {
  if (message.from !== 'me') {
    return 'sent'
  }

  if (message.status === 'pending') return 'pending'
  if (message.status === 'failed') return 'failed'

  const markers = findMarkersFor(message.messageId, allMessages)
  const hasDisplayed = markers.some((m) => m.markerType === 'displayed')

  if (hasDisplayed || readingUi.has(message.messageId)) {
    return 'reading'
  }

  return 'sent'
}
