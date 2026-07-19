// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'package:alfred_client/machines/messaging/conversation_load_machine.dart';
import 'package:alfred_client/machines/messaging/messaging_conversation_state.dart';
import 'package:alfred_client/machines/messaging/messaging_coordinator.dart';
import 'package:alfred_client/machines/messaging/messaging_effects.dart';
import 'package:alfred_client/machines/messaging/outbound_send_machine.dart';
import 'package:alfred_client/machines/messaging/realtime_attachment_machine.dart';
import 'package:alfred_client/models/message.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _RecordingEffects implements MessagingEffects {
  int fetchCount = 0;
  int markReadCount = 0;
  int attachCount = 0;

  @override
  bool get isDisposed => false;

  @override
  bool ensureValidSession() => true;

  @override
  Future<bool> fetchAndSetMessages() async {
    fetchCount++;
    return true;
  }

  @override
  Future<void> enrichAuthorNamesIfNeeded() async {}

  @override
  Future<void> markRead() async => markReadCount++;

  @override
  RealtimeChannel? attachRealtime(void Function(ChatMessage message) onMessage) {
    attachCount++;
    return null;
  }

  @override
  void disposeRealtime(RealtimeChannel? channel) {}

  @override
  void startRetryTimer(void Function() onTick) {}

  @override
  void stopRetryTimer() {}

  @override
  Future<void> restoreFailedFromQueue() async {}

  @override
  Future<void> sendText(String body) async {}

  @override
  Future<void> sendGif(Uint8List bytes) async {}

  @override
  Future<void> sendImage({required Uint8List bytes, String? caption}) async {}

  @override
  Future<void> sendVideoFromPicker({
    required PlatformFile file,
    String? caption,
  }) async {}

  @override
  Future<void> sendVideo({
    required Uint8List bytes,
    required String extension,
    required String mime,
    required int durationSeconds,
    String? caption,
  }) async {}

  @override
  Future<void> sendVoice({
    required Uint8List bytes,
    required int durationMs,
  }) async {}

  @override
  Future<void> sendLocation({
    required double latitude,
    required double longitude,
  }) async {}

  @override
  Future<void> retryMessage(String clientId) async {}

  @override
  Future<void> processRetries() async {}

  @override
  void disposeQueue() {}
}

void main() {
  group('ConversationLoadMachine', () {
    test('LoadMessages → loading', () {
      final machine = ConversationLoadMachine()
        ..state = ConversationLoadState.ready;
      machine.send(const LoadMessages());
      expect(machine.state, ConversationLoadState.loading);
    });

    test('RefreshConversation → loading', () {
      final machine = ConversationLoadMachine()
        ..state = ConversationLoadState.ready;
      machine.send(const RefreshConversation());
      expect(machine.state, ConversationLoadState.loading);
    });

    test('SessionExpired → sessionBlocked', () {
      final machine = ConversationLoadMachine();
      machine.send(const SessionExpired());
      expect(machine.state, ConversationLoadState.sessionBlocked);
    });
  });

  group('OutboundSendMachine', () {
    test('SendStarted → sending → ContentSent → idle', () {
      final machine = OutboundSendMachine();
      machine.send(const SendStarted());
      expect(machine.state, OutboundSendState.sending);
      machine.send(const ContentSent());
      expect(machine.state, OutboundSendState.idle);
    });

    test('ContentSendFailed → failedQueue', () {
      final machine = OutboundSendMachine()..state = OutboundSendState.sending;
      machine.send(const ContentSendFailed());
      expect(machine.state, OutboundSendState.failedQueue);
    });
  });

  group('RealtimeAttachmentMachine', () {
    test('AttachRealtime / DetachRealtime', () {
      final machine = RealtimeAttachmentMachine();
      machine.send(const AttachRealtime());
      expect(machine.state, RealtimeAttachmentState.attached);
      machine.send(const DetachRealtime());
      expect(machine.state, RealtimeAttachmentState.detached);
    });
  });

  group('MessagingCoordinator', () {
    test('init wires load, markRead, realtime', () async {
      final effects = _RecordingEffects();
      final coordinator = MessagingCoordinator(
        state: MessagingConversationState(),
        effects: effects,
        onChanged: () {},
      );

      await coordinator.init();

      expect(coordinator.loadMachine.state, ConversationLoadState.ready);
      expect(
        coordinator.realtimeMachine.state,
        RealtimeAttachmentState.attached,
      );
      expect(effects.fetchCount, 1);
      expect(effects.markReadCount, 1);
      expect(effects.attachCount, 1);
    });
  });
}
