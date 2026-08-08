// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'package:alfred_client/machines/messaging/message_actions_machine.dart';
import 'package:alfred_client/machines/messaging/conversation_message_store.dart';
import 'package:alfred_client/machines/messaging/conversation_load_machine.dart';
import 'package:alfred_client/models/conversation_scope.dart';
import 'package:alfred_client/machines/messaging/messaging_conversation_state.dart';
import 'package:alfred_client/machines/messaging/messaging_coordinator.dart';
import 'package:alfred_client/machines/messaging/messaging_effects.dart';
import 'package:alfred_client/machines/messaging/outbound_send_machine.dart';
import 'package:alfred_client/machines/messaging/realtime_attachment_machine.dart';
import 'package:alfred_client/models/message.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/fake_messaging_services.dart';

class _RecordingEffects implements MessagingEffects {
  _RecordingEffects()
      : scope = testConversationScope(userId: 'user-a', peerProfileId: 'peer-b'),
        messageStore = ConversationMessageStore() {
    messageStore.bindCommittedScope(scope);
  }

  @override
  final ConversationScope scope;
  @override
  final ConversationMessageStore messageStore;

  int fetchCount = 0;
  int prependCount = 0;
  int markReadCount = 0;
  int attachCount = 0;

  @override
  bool get isDisposed => false;

  @override
  bool ensureValidSession() => true;

  @override
  bool get isScopeActive => true;

  @override
  Future<bool> fetchAndSetMessages() async {
    fetchCount++;
    return true;
  }

  @override
  Future<bool> fetchAndPrependOlderMessages() async {
    prependCount++;
    return true;
  }

  @override
  Future<void> enrichAuthorNamesIfNeeded() async {}

  @override
  bool get hasGroupPeerAuthorEnrichment => false;

  @override
  Future<void> markRead() async => markReadCount++;

  @override
  RealtimeChannel? attachRealtime(
    void Function(ChatMessage message) onMessage, {
    void Function(String logicalMessageId)? onReactionFact,
  }) {
    attachCount++;
    return null;
  }

  @override
  Future<void> applyReaction({
    required String logicalMessageId,
    required String emoji,
  }) async {}

  @override
  Future<void> withdrawReaction({required String logicalMessageId}) async {}

  @override
  Future<void> refreshReactionsForLogicalId(String logicalMessageId) async {}

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

    test('ConversationUnavailable → sessionBlocked', () {
      final machine = ConversationLoadMachine();
      machine.send(const ConversationUnavailable());
      expect(machine.state, ConversationLoadState.sessionBlocked);
    });

    test('LoadFailed → ready', () {
      final machine = ConversationLoadMachine()
        ..state = ConversationLoadState.loading;
      machine.send(const LoadFailed());
      expect(machine.state, ConversationLoadState.ready);
    });

    test('ConversationReady → ready', () {
      final machine = ConversationLoadMachine()
        ..state = ConversationLoadState.loading;
      machine.send(const ConversationReady());
      expect(machine.state, ConversationLoadState.ready);
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

    test('RetryFailedSend → sending', () {
      final machine = OutboundSendMachine()..state = OutboundSendState.failedQueue;
      machine.send(const RetryFailedSend());
      expect(machine.state, OutboundSendState.sending);
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

    test('loadOlderMessages delegates to effects when more history exists', () async {
      final effects = _RecordingEffects();
      effects.messageStore.applyLoadedMessages(
        effects.scope,
        [
          ChatMessage(
            id: '1',
            body: 'x',
            timeLabel: '12:00',
            isMine: true,
            senderId: 'user-a',
            createdAt: DateTime.utc(2026, 7, 1),
          ),
        ],
        hasMoreOlder: true,
      );
      final coordinator = MessagingCoordinator(
        state: MessagingConversationState(),
        effects: effects,
        onChanged: () {},
      );
      coordinator.loadMachine.send(const ConversationReady());

      await coordinator.loadOlderMessages();

      expect(effects.prependCount, 1);
    });
  });

  group('MessageActionsMachine', () {
    test('OpenMessageActions → open with target', () {
      final machine = MessageActionsMachine();
      machine.send(const OpenMessageActions('msg-1'));
      expect(machine.state, MessageActionsState.open);
      expect(machine.targetMessageId, 'msg-1');
    });

    test('ApplyReaction keeps open until close', () {
      final machine = MessageActionsMachine();
      machine.send(const OpenMessageActions('msg-1'));
      machine.send(const ApplyReaction());
      expect(machine.state, MessageActionsState.open);
      machine.send(const CloseMessageActions());
      expect(machine.state, MessageActionsState.closed);
    });
  });
}
