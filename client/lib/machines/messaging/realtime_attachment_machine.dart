// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../models/message.dart';

enum RealtimeAttachmentState { detached, attached }

sealed class RealtimeAttachmentEvent { const RealtimeAttachmentEvent(); }
/// Adapter interno — dominio: `OpenConversation` (via coordinator).
final class AttachRealtime extends RealtimeAttachmentEvent { const AttachRealtime(); }
/// Adapter interno — dominio: `CloseConversation` (via coordinator.dispose).
final class DetachRealtime extends RealtimeAttachmentEvent { const DetachRealtime(); }
/// Adapter interno — dominio: `ConversationUpdated` (INSERT messaggi + UPDATE spunte).
final class RealtimeReceived extends RealtimeAttachmentEvent {
  const RealtimeReceived(this.message);
  final ChatMessage message;
}

class RealtimeAttachmentMachine {
  RealtimeAttachmentState state = RealtimeAttachmentState.detached;
  void send(RealtimeAttachmentEvent event) {
    switch (event) {
      case AttachRealtime(): state = RealtimeAttachmentState.attached;
      case DetachRealtime(): state = RealtimeAttachmentState.detached;
      case RealtimeReceived(): break;
    }
  }
}
