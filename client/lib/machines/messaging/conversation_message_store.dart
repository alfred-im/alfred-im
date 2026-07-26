// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';

import '../../models/conversation_scope.dart';
import '../../models/message.dart';

/// Fase caricamento lista messaggi 1:1 — proiezione di [OpenConversation].
enum ConversationLoadPhase {
  empty,
  loading,
  ready,
}

/// Snapshot immutabile per la UI.
@immutable
class ConversationMessageSnapshot {
  const ConversationMessageSnapshot({
    this.messages = const [],
    this.phase = ConversationLoadPhase.empty,
    this.error,
    this.hasMoreOlder = false,
    this.isLoadingOlder = false,
  });

  final List<ChatMessage> messages;
  final ConversationLoadPhase phase;
  final String? error;
  final bool hasMoreOlder;
  final bool isLoadingOlder;

  static const empty = ConversationMessageSnapshot();
}

/// Unica autorità per la lista messaggi chat 1:1 legata a [ConversationScope] commesso.
class ConversationMessageStore extends ChangeNotifier {
  ConversationScope? _committedScope;
  ConversationMessageSnapshot _snapshot = ConversationMessageSnapshot.empty;

  ConversationScope? get committedScope => _committedScope;

  ConversationMessageSnapshot get snapshot => _snapshot;

  ConversationMessageSnapshot snapshotFor(ConversationScope scope) {
    if (!_matches(scope)) return ConversationMessageSnapshot.empty;
    return _snapshot;
  }

  void bindCommittedScope(ConversationScope? scope) {
    if (_committedScope == scope) return;
    _committedScope = scope;
    _purge();
    notifyListeners();
  }

  void _purge() {
    _snapshot = ConversationMessageSnapshot.empty;
  }

  bool _matches(ConversationScope scope) =>
      _committedScope != null && _committedScope == scope;

  bool beginLoad(ConversationScope scope) {
    if (!_matches(scope)) return false;
    _snapshot = const ConversationMessageSnapshot(
      phase: ConversationLoadPhase.loading,
    );
    notifyListeners();
    return true;
  }

  bool applyLoadedMessages(
    ConversationScope scope,
    List<ChatMessage> messages, {
    required bool hasMoreOlder,
  }) {
    if (!_matches(scope)) return false;
    _snapshot = ConversationMessageSnapshot(
      messages: List.unmodifiable(messages),
      phase: ConversationLoadPhase.ready,
      hasMoreOlder: hasMoreOlder,
    );
    notifyListeners();
    return true;
  }

  bool setLoadingOlder(ConversationScope scope, bool value) {
    if (!_matches(scope)) return false;
    _snapshot = ConversationMessageSnapshot(
      messages: _snapshot.messages,
      phase: _snapshot.phase,
      error: _snapshot.error,
      hasMoreOlder: _snapshot.hasMoreOlder,
      isLoadingOlder: value,
    );
    notifyListeners();
    return true;
  }

  bool mutateMessages(
    ConversationScope scope,
    List<ChatMessage> Function(List<ChatMessage> current) update,
  ) {
    if (!_matches(scope)) return false;
    final next = update(_snapshot.messages);
    _snapshot = ConversationMessageSnapshot(
      messages: List.unmodifiable(next),
      phase: _snapshot.phase,
      error: _snapshot.error,
      hasMoreOlder: _snapshot.hasMoreOlder,
      isLoadingOlder: _snapshot.isLoadingOlder,
    );
    notifyListeners();
    return true;
  }

  List<ChatMessage> messagesIfActive(ConversationScope scope) =>
      snapshotFor(scope).messages;
}
