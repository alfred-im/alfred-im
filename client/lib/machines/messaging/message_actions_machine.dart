// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

enum MessageActionsState { closed, open }

sealed class MessageActionsEvent {
  const MessageActionsEvent();
}

final class OpenMessageActions extends MessageActionsEvent {
  const OpenMessageActions(this.messageId);
  final String messageId;
}

final class CloseMessageActions extends MessageActionsEvent {
  const CloseMessageActions();
}

final class ApplyReaction extends MessageActionsEvent {
  const ApplyReaction();
}

final class WithdrawReaction extends MessageActionsEvent {
  const WithdrawReaction();
}

class MessageActionsMachine {
  MessageActionsState state = MessageActionsState.closed;
  String? targetMessageId;

  void send(MessageActionsEvent event) {
    switch (event) {
      case OpenMessageActions(:final messageId):
        state = MessageActionsState.open;
        targetMessageId = messageId;
      case CloseMessageActions():
        state = MessageActionsState.closed;
        targetMessageId = null;
      case ApplyReaction():
      case WithdrawReaction():
        if (state == MessageActionsState.open) {
          state = MessageActionsState.open;
        }
    }
  }
}
