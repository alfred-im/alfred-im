// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/machines/groups/groups_machine.dart';
import 'package:alfred_client/models/chat_peer.dart';
import 'package:alfred_client/models/message.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_messaging_services.dart';

class _RecordingGroupHomeEffects implements GroupHomeEffects {
  int loadCount = 0;

  @override
  Future<void> loadHome() async {
    loadCount++;
  }
}

class _RecordingGroupMessagesEffects implements GroupMessagesEffects {
  int loadCount = 0;
  int attachCount = 0;
  int disposeCount = 0;
  int broadcastCount = 0;
  int realtimeCount = 0;

  @override
  Future<void> loadMessages() async {
    loadCount++;
  }

  @override
  void attachRealtime() {
    attachCount++;
  }

  @override
  void disposeRealtime() {
    disposeCount++;
  }

  @override
  Future<void> runBroadcast() async {
    broadcastCount++;
  }

  @override
  void onRealtimeMessage(ChatMessage message) {
    realtimeCount++;
  }
}

ChatMessage _message({String id = 'm1'}) => ChatMessage(
      id: id,
      body: 'hello',
      timeLabel: '',
      isMine: false,
      createdAt: DateTime.utc(2026, 7, 1),
    );

void main() {
  group('GroupHomeMachine', () {
    test('starts loading', () {
      final machine = GroupHomeMachine(_RecordingGroupHomeEffects());

      expect(machine.loadState, GroupHomeLoadState.loading);
    });

    test('LoadGroupHome calls effect', () async {
      final effects = _RecordingGroupHomeEffects();
      final machine = GroupHomeMachine(effects)
        ..loadState = GroupHomeLoadState.ready;

      await machine.send(const LoadGroupHome());

      expect(machine.loadState, GroupHomeLoadState.loading);
      expect(effects.loadCount, 1);
    });

    test('GroupHomeLoaded → ready and stores snapshot', () async {
      const profile = ProfileSummary(
        id: 'group-1',
        displayName: 'Famiglia',
        username: 'famiglia',
      );
      final snapshot = GroupHomeSnapshot(
        createdAt: DateTime.utc(2026, 3, 12),
        totalMessageCount: 2,
        conversationTile: ChatPeer.fromProfile(profile: profile),
      );
      final machine = GroupHomeMachine(_RecordingGroupHomeEffects());

      await machine.send(GroupHomeLoaded(snapshot));

      expect(machine.loadState, GroupHomeLoadState.ready);
      expect(machine.snapshot, snapshot);
    });

    test('GroupHomeLoadFailed → ready', () async {
      final machine = GroupHomeMachine(_RecordingGroupHomeEffects());

      await machine.send(const GroupHomeLoadFailed());

      expect(machine.loadState, GroupHomeLoadState.ready);
    });
  });

  group('GroupMessagesMachine', () {
    test('starts loading with detached realtime', () {
      final machine = GroupMessagesMachine(_RecordingGroupMessagesEffects());

      expect(machine.loadState, GroupMessagesLoadState.loading);
      expect(machine.broadcastState, GroupBroadcastState.idle);
      expect(machine.realtimeState, GroupRealtimeState.detached);
    });

    test('InitGroupMessages loads and attaches realtime', () async {
      final effects = _RecordingGroupMessagesEffects();
      final machine = GroupMessagesMachine(effects);

      await machine.send(const InitGroupMessages());

      expect(effects.loadCount, 1);
      expect(effects.attachCount, 1);
      expect(machine.realtimeState, GroupRealtimeState.attached);
    });

    test('BroadcastRequested runs broadcast effect', () async {
      final effects = _RecordingGroupMessagesEffects();
      final machine = GroupMessagesMachine(effects);

      await machine.send(const BroadcastRequested());

      expect(machine.broadcastState, GroupBroadcastState.sending);
      expect(effects.broadcastCount, 1);
    });

    test('BroadcastAcknowledged returns to idle', () async {
      final machine = GroupMessagesMachine(_RecordingGroupMessagesEffects())
        ..broadcastState = GroupBroadcastState.sending;

      await machine.send(const BroadcastAcknowledged());

      expect(machine.broadcastState, GroupBroadcastState.idle);
    });

    test('OwnerRealtimeReceived forwards to effect', () async {
      final effects = _RecordingGroupMessagesEffects();
      final machine = GroupMessagesMachine(effects);

      await machine.send(OwnerRealtimeReceived(_message()));

      expect(effects.realtimeCount, 1);
    });

    test('DisposeGroupMessages detaches realtime', () async {
      final effects = _RecordingGroupMessagesEffects();
      final machine = GroupMessagesMachine(effects)
        ..realtimeState = GroupRealtimeState.attached;

      await machine.send(const DisposeGroupMessages());

      expect(effects.disposeCount, 1);
      expect(machine.realtimeState, GroupRealtimeState.detached);
    });
  });

  group('buildGroupHomeAggregates', () {
    test('excludes owner and builds conversation tile from last message', () async {
      const groupProfile = ProfileSummary(
        id: 'group-1',
        displayName: 'Famiglia',
        username: 'famiglia',
      );
      const mario = ProfileSummary(
        id: 'mario',
        displayName: 'Mario',
        username: 'mario',
      );

      final client = createTestSupabaseClient();
      final profileService = FakeProfileService(client)
        ..profilesById['mario'] = mario;

      final aggregates = await buildGroupHomeAggregates(
        messages: [
          ChatMessage(
            id: 'm1',
            body: 'ciao',
            timeLabel: '',
            isMine: false,
            originalAuthorId: 'mario',
            createdAt: DateTime.utc(2026, 7, 1),
          ),
          ChatMessage(
            id: 'm2',
            body: 'broadcast',
            timeLabel: '',
            isMine: true,
            originalAuthorId: 'group-1',
            createdAt: DateTime.utc(2026, 7, 2),
          ),
        ],
        profile: groupProfile,
        currentUserId: 'group-1',
        profileService: profileService,
      );

      expect(aggregates.activeAuthors, hasLength(1));
      expect(aggregates.activeAuthors.single.profile.id, 'mario');
      expect(aggregates.conversationTile.preview, 'broadcast');
    });
  });
}
