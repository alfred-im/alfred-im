import { memo } from 'react'
import { formatDateSeparator, formatMessageTime } from '../utils/date'
import type { Message } from '../services/messages'
import type { VirtualMessage } from '../types/ui-message'
import type { CheckmarkLevel } from '../types/message-states'
import { resolveCheckmarkLevel } from '../utils/checkmark'
import { isVirtualMessage } from '../utils/message-reconcile'

type ChatItem = Message | VirtualMessage

interface MessageItemProps {
  message: ChatItem
  showDate: boolean
  allMessages: Message[]
  readingUi: ReadonlySet<string>
  virtualSendState: { sent: ReadonlySet<string>; failed: ReadonlySet<string> }
}

function virtualCheckmarkLevel(
  virtual: VirtualMessage,
  virtualSendState: MessageItemProps['virtualSendState']
): CheckmarkLevel {
  if (virtual.kind !== 'outgoing') return 'sent'
  const tempId = virtual.tempId
  if (tempId && virtualSendState.failed.has(tempId)) return 'failed'
  if (tempId && virtualSendState.sent.has(tempId)) return 'sent'
  return 'pending'
}

function renderCheckmarks(level: CheckmarkLevel) {
  switch (level) {
    case 'pending':
      return <span className="chat-page__checkmark-pending">🕐</span>
    case 'sent':
      return <span className="chat-page__checkmark-single">✓</span>
    case 'reading':
      return <span className="chat-page__checkmark-double-blue">✓✓</span>
    case 'failed':
      return <span className="chat-page__checkmark-failed">✗</span>
    default:
      return <span className="chat-page__checkmark-single">✓</span>
  }
}

export const MessageItem = memo(function MessageItem({
  message,
  showDate,
  allMessages,
  readingUi,
  virtualSendState,
}: MessageItemProps) {
  const isMe = message.from === 'me'

  if (isVirtualMessage(message)) {
    const checkmark = isMe ? virtualCheckmarkLevel(message, virtualSendState) : undefined

    return (
      <div>
        {showDate && (
          <div className="chat-page__date-separator">
            {formatDateSeparator(message.timestamp)}
          </div>
        )}
        <div className={`chat-page__message ${isMe ? 'chat-page__message--me' : 'chat-page__message--them'}`}>
          <div className="chat-page__message-bubble">
            <p className="chat-page__message-body">{message.body}</p>
            <div className="chat-page__message-meta">
              <span className="chat-page__message-time">
                {formatMessageTime(message.timestamp)}
              </span>
              {isMe && checkmark && (
                <span className="chat-page__message-status" aria-label={`Messaggio ${checkmark}`}>
                  {renderCheckmarks(checkmark)}
                </span>
              )}
            </div>
          </div>
        </div>
      </div>
    )
  }

  if (message.body && message.body.trim().length > 0) {
    const checkmark = isMe
      ? resolveCheckmarkLevel(message, allMessages, readingUi)
      : undefined

    return (
      <div>
        {showDate && (
          <div className="chat-page__date-separator">
            {formatDateSeparator(message.timestamp)}
          </div>
        )}
        <div className={`chat-page__message ${isMe ? 'chat-page__message--me' : 'chat-page__message--them'}`}>
          <div className="chat-page__message-bubble">
            <p className="chat-page__message-body">{message.body}</p>
            <div className="chat-page__message-meta">
              <span className="chat-page__message-time">
                {formatMessageTime(message.timestamp)}
              </span>
              {isMe && checkmark && (
                <span className="chat-page__message-status" aria-label={`Messaggio ${checkmark}`}>
                  {renderCheckmarks(checkmark)}
                </span>
              )}
            </div>
          </div>
        </div>
      </div>
    )
  }

  if (message.markerType) {
    return null
  }

  return (
    <div>
      {showDate && (
        <div className="chat-page__date-separator">
          {formatDateSeparator(message.timestamp)}
        </div>
      )}
      <div className={`chat-page__message ${isMe ? 'chat-page__message--me' : 'chat-page__message--them'}`}>
        <div className="chat-page__message-bubble" style={{ opacity: 0.5, fontSize: '0.75rem', fontStyle: 'italic' }}>
          <p className="chat-page__message-body">[Messaggio vuoto - ID: {message.messageId.substring(0, 8)}]</p>
          <div className="chat-page__message-meta">
            <span className="chat-page__message-time">
              {formatMessageTime(message.timestamp)}
            </span>
          </div>
        </div>
      </div>
    </div>
  )
})
