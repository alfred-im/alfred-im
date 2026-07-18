// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../models/message.dart';

enum RealtimeAttachmentState { detached, attached }

sealed class RealtimeAttachmentEvent { const RealtimeAttachmentEvent(); }
final class AttachRealtime extends RealtimeAttachmentEvent { const AttachRealtime(); }
final class DetachRealtime extends RealtimeAttachmentEvent { const DetachRealtime(); }
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
