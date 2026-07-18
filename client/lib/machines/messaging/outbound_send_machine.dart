// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

enum OutboundSendState { idle, sending, failedQueue }

sealed class OutboundSendEvent { const OutboundSendEvent(); }
final class SendStarted extends OutboundSendEvent { const SendStarted(); }
final class SendAcknowledged extends OutboundSendEvent { const SendAcknowledged(); }
final class SendFailed extends OutboundSendEvent { const SendFailed(); }
final class RetryStarted extends OutboundSendEvent { const RetryStarted(); }
final class QueueEmptied extends OutboundSendEvent { const QueueEmptied(); }
final class FailedQueueRestored extends OutboundSendEvent { const FailedQueueRestored(); }

class OutboundSendMachine {
  OutboundSendState state = OutboundSendState.idle;
  void send(OutboundSendEvent event) {
    switch (event) {
      case SendStarted(): case RetryStarted(): state = OutboundSendState.sending;
      case SendAcknowledged(): state = OutboundSendState.idle;
      case SendFailed(): state = OutboundSendState.failedQueue;
      case FailedQueueRestored():
        if (state != OutboundSendState.sending) state = OutboundSendState.failedQueue;
      case QueueEmptied():
        if (state != OutboundSendState.sending) state = OutboundSendState.idle;
    }
  }
}
