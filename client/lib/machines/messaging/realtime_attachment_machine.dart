// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

enum RealtimeAttachmentState { detached, attached }

sealed class RealtimeAttachmentEvent { const RealtimeAttachmentEvent(); }
/// Adapter interno — dominio: `OpenConversation` (via coordinator).
final class AttachRealtime extends RealtimeAttachmentEvent { const AttachRealtime(); }
/// Adapter interno — dominio: `CloseConversation` (via coordinator.dispose).
final class DetachRealtime extends RealtimeAttachmentEvent { const DetachRealtime(); }

class RealtimeAttachmentMachine {
  RealtimeAttachmentState state = RealtimeAttachmentState.detached;
  void send(RealtimeAttachmentEvent event) {
    switch (event) {
      case AttachRealtime(): state = RealtimeAttachmentState.attached;
      case DetachRealtime(): state = RealtimeAttachmentState.detached;
    }
  }
}
