// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../models/chat_peer.dart';
import '../../models/group_active_author.dart';
import '../../models/message.dart';

/// Stato caricamento home gruppo — `docs/model/uml/groups/groups-state.puml`.
enum GroupHomeLoadState {
  loading,
  ready,
}

/// Stato caricamento conversazione gruppo.
enum GroupMessagesLoadState {
  loading,
  ready,
}

/// Stato invio broadcast serializzato.
enum GroupBroadcastState {
  idle,
  sending,
}

/// Regione parallela subscription Realtime owner.
enum GroupRealtimeState {
  detached,
  attached,
}

/// Eventi home — `docs/domain/groups/commands-and-events.md`.
sealed class GroupHomeEvent {
  const GroupHomeEvent();
}

final class LoadGroupHome extends GroupHomeEvent {
  const LoadGroupHome();
}

final class GroupHomeLoaded extends GroupHomeEvent {
  const GroupHomeLoaded();
}

final class GroupHomeLoadFailed extends GroupHomeEvent {
  const GroupHomeLoadFailed();
}

/// Eventi conversazione gruppo.
sealed class GroupMessagesEvent {
  const GroupMessagesEvent();
}

final class InitGroupMessages extends GroupMessagesEvent {
  const InitGroupMessages();
}

final class LoadGroupMessages extends GroupMessagesEvent {
  const LoadGroupMessages();
}

final class GroupMessagesLoaded extends GroupMessagesEvent {
  const GroupMessagesLoaded();
}

final class GroupMessagesLoadFailed extends GroupMessagesEvent {
  const GroupMessagesLoadFailed();
}

final class BroadcastRequested extends GroupMessagesEvent {
  const BroadcastRequested();
}

final class BroadcastAcknowledged extends GroupMessagesEvent {
  const BroadcastAcknowledged();
}

final class BroadcastFailed extends GroupMessagesEvent {
  const BroadcastFailed();
}

final class OwnerRealtimeReceived extends GroupMessagesEvent {
  const OwnerRealtimeReceived(this.message);
  final ChatMessage message;
}

final class DisposeGroupMessages extends GroupMessagesEvent {
  const DisposeGroupMessages();
}

/// Effetti home gruppo.
abstract class GroupHomeEffects {
  Future<void> loadHome();
}

/// Effetti conversazione gruppo.
abstract class GroupMessagesEffects {
  Future<void> loadMessages();

  void attachRealtime();

  void disposeRealtime();

  Future<void> runBroadcast();

  void onRealtimeMessage(ChatMessage message);
}

/// Interprete statechart home gruppo.
class GroupHomeMachine {
  GroupHomeMachine(this._effects);

  final GroupHomeEffects _effects;

  GroupHomeLoadState loadState = GroupHomeLoadState.loading;

  Future<void> send(GroupHomeEvent event) async {
    switch (event) {
      case LoadGroupHome():
        loadState = GroupHomeLoadState.loading;
        await _effects.loadHome();
      case GroupHomeLoaded():
        loadState = GroupHomeLoadState.ready;
      case GroupHomeLoadFailed():
        loadState = GroupHomeLoadState.ready;
    }
  }
}

/// Interprete statechart messaggi gruppo.
class GroupMessagesMachine {
  GroupMessagesMachine(this._effects);

  final GroupMessagesEffects _effects;

  GroupMessagesLoadState loadState = GroupMessagesLoadState.loading;
  GroupBroadcastState broadcastState = GroupBroadcastState.idle;
  GroupRealtimeState realtimeState = GroupRealtimeState.detached;

  Future<void> send(GroupMessagesEvent event) async {
    switch (event) {
      case InitGroupMessages():
        loadState = GroupMessagesLoadState.loading;
        await _effects.loadMessages();
        _effects.attachRealtime();
        realtimeState = GroupRealtimeState.attached;
      case LoadGroupMessages():
        loadState = GroupMessagesLoadState.loading;
        await _effects.loadMessages();
      case GroupMessagesLoaded():
        loadState = GroupMessagesLoadState.ready;
      case GroupMessagesLoadFailed():
        loadState = GroupMessagesLoadState.ready;
      case BroadcastRequested():
        if (broadcastState == GroupBroadcastState.sending) return;
        broadcastState = GroupBroadcastState.sending;
        await _effects.runBroadcast();
      case BroadcastAcknowledged():
        broadcastState = GroupBroadcastState.idle;
      case BroadcastFailed():
        broadcastState = GroupBroadcastState.idle;
      case OwnerRealtimeReceived(:final message):
        _effects.onRealtimeMessage(message);
      case DisposeGroupMessages():
        _effects.disposeRealtime();
        realtimeState = GroupRealtimeState.detached;
    }
  }
}

/// Dati aggregati home gruppo dopo load.
class GroupHomeSnapshot {
  const GroupHomeSnapshot({
    this.createdAt,
    this.totalMessageCount = 0,
    this.activeAuthors = const [],
    this.conversationTile,
  });

  final DateTime? createdAt;
  final int totalMessageCount;
  final List<GroupActiveAuthor> activeAuthors;
  final ChatPeer? conversationTile;
}
