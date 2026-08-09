// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

enum OutboundSendState { idle, sending }

sealed class OutboundSendEvent { const OutboundSendEvent(); }

/// Adapter interno — inizio invio (dominio: `SendContent`).
final class SendStarted extends OutboundSendEvent { const SendStarted(); }

/// Dominio: evento `ContentSent`.
final class ContentSent extends OutboundSendEvent { const ContentSent(); }

/// Dominio: evento `ContentSendFailed`.
final class ContentSendFailed extends OutboundSendEvent { const ContentSendFailed(); }

/// Dominio: `RetryFailedSend`.
final class RetryFailedSend extends OutboundSendEvent { const RetryFailedSend(); }

class OutboundSendMachine {
  OutboundSendState state = OutboundSendState.idle;
  void send(OutboundSendEvent event) {
    switch (event) {
      case SendStarted():
      case RetryFailedSend():
        state = OutboundSendState.sending;
      case ContentSent():
      case ContentSendFailed():
        state = OutboundSendState.idle;
    }
  }
}
