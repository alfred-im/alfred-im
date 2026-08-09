// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../models/chat_peer.dart';
import '../../models/group_active_author.dart';
import '../../models/message.dart';
import 'groups_effects.dart';

/// Stato caricamento home gruppo — regione `GroupHomeLoad` in
/// `docs/model/uml/groups/groups-state.puml`.
enum GroupHomeLoadState {
  loading,
  ready,
}

/// Stato caricamento conversazione gruppo — regione `GroupMessagesLoad`.
enum GroupMessagesLoadState {
  loading,
  ready,
}

/// Stato invio broadcast serializzato — regione `GroupBroadcast`.
enum GroupBroadcastState {
  idle,
  sending,
}

/// Eventi home — `docs/domain/groups/commands-and-events.md`.
sealed class GroupHomeEvent {
  const GroupHomeEvent();
}

final class LoadGroupHome extends GroupHomeEvent {
  const LoadGroupHome();
}

final class GroupHomeLoaded extends GroupHomeEvent {
  const GroupHomeLoaded(this.snapshot);
  final GroupHomeSnapshot snapshot;
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

/// Interprete statechart home gruppo (`GroupHomeLoad`).
class GroupHomeMachine {
  GroupHomeMachine(this._effects);

  final GroupHomeEffects _effects;

  GroupHomeLoadState loadState = GroupHomeLoadState.loading;
  GroupHomeSnapshot? snapshot;

  Future<void> send(GroupHomeEvent event) async {
    switch (event) {
      case LoadGroupHome():
        loadState = GroupHomeLoadState.loading;
        await _effects.loadHome();
      case GroupHomeLoaded(:final snapshot):
        this.snapshot = snapshot;
        loadState = GroupHomeLoadState.ready;
      case GroupHomeLoadFailed():
        loadState = GroupHomeLoadState.ready;
    }
  }
}

/// Interprete statechart messaggi gruppo (`GroupMessagesLoad` +
/// `GroupBroadcast` + `GroupRealtime`).
class GroupMessagesMachine {
  GroupMessagesMachine(this._effects);

  final GroupMessagesEffects _effects;

  GroupMessagesLoadState loadState = GroupMessagesLoadState.loading;
  GroupBroadcastState broadcastState = GroupBroadcastState.idle;

  Future<void> send(GroupMessagesEvent event) async {
    switch (event) {
      case InitGroupMessages():
        loadState = GroupMessagesLoadState.loading;
        await _effects.loadMessages();
        _effects.attachRealtime();
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
