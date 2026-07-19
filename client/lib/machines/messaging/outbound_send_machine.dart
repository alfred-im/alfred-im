// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

enum OutboundSendState { idle, sending, failedQueue }

sealed class OutboundSendEvent { const OutboundSendEvent(); }

/// Adapter interno — inizio invio (`SendContent`).
final class SendStarted extends OutboundSendEvent { const SendStarted(); }

/// Dominio: evento `ContentSent`.
final class ContentSent extends OutboundSendEvent { const ContentSent(); }

/// Dominio: evento `ContentSendFailed`.
final class ContentSendFailed extends OutboundSendEvent { const ContentSendFailed(); }

/// Dominio: `RetryFailedSend`.
final class RetryFailedSend extends OutboundSendEvent { const RetryFailedSend(); }

final class QueueEmptied extends OutboundSendEvent { const QueueEmptied(); }
final class FailedQueueRestored extends OutboundSendEvent {
  const FailedQueueRestored();
}

class OutboundSendMachine {
  OutboundSendState state = OutboundSendState.idle;
  void send(OutboundSendEvent event) {
    switch (event) {
      case SendStarted():
      case RetryFailedSend():
        state = OutboundSendState.sending;
      case ContentSent():
        state = OutboundSendState.idle;
      case ContentSendFailed():
        state = OutboundSendState.failedQueue;
      case FailedQueueRestored():
        if (state != OutboundSendState.sending) {
          state = OutboundSendState.failedQueue;
        }
      case QueueEmptied():
        if (state != OutboundSendState.sending) state = OutboundSendState.idle;
    }
  }
}
