// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../machines/inbox/inbox_effects.dart';
import '../machines/inbox/inbox_machine.dart';
import '../models/chat_peer.dart';
import '../services/inbox_service.dart';
import '../utils/list_filter.dart';

/// Stato inbox esposto alla UI tramite [InboxController].
class InboxState {
  List<ChatPeer> peers = [];
  bool isLoading = true;
  String? error;
}

/// Orchestrazione load, filtro e realtime inbox.
class InboxCoordinator {
  InboxCoordinator({
    required String userId,
    required InboxService inboxService,
    required void Function() onStateChanged,
    this.enableRealtime = true,
    this.enableInboxLoads = true,
  })  : _userId = userId,
        _inboxService = inboxService,
        _onStateChanged = onStateChanged {
    _machine = InboxMachine(_LiveInboxEffects._(this));
    unawaited(_bootstrap());
  }

  final String _userId;
  final InboxService _inboxService;
  final void Function() _onStateChanged;
  final bool enableRealtime;
  final bool enableInboxLoads;
  late final InboxMachine _machine;
  final InboxState state = InboxState();
  RealtimeChannel? _channel;
  bool _realtimeAttached = false;

  List<ChatPeer> get filteredPeers => filterByQueryFields(
        state.peers,
        _machine.searchQuery,
        (peer) => [peer.displayName, peer.preview, peer.address ?? ''],
      );

  ChatPeer? findByProfileId(String profileId) {
    for (final peer in state.peers) {
      if (peer.profileId == profileId) return peer;
    }
    return null;
  }

  void setSearchQuery(String value) {
    unawaited(_machine.send(SetSearchQuery(value)));
    _notify();
  }

  Future<void> load({bool showLoadingIndicator = true}) =>
      _machine.send(LoadInbox(showLoadingIndicator: showLoadingIndicator));

  void dispose() {
    _inboxService.disposeChannel(_channel);
  }

  Future<void> _bootstrap() async {
    if (!enableInboxLoads) {
      state.isLoading = false;
      _machine.loadState = InboxLoadState.ready;
      _notify();
      return;
    }
    await load();
    if (enableRealtime) _attachRealtime();
  }

  void _attachRealtime() {
    if (_realtimeAttached) return;
    _realtimeAttached = true;
    _channel = _inboxService.subscribeToInbox(_userId, () => load());
  }

  void _syncLoadingFromMachine() {
    state.isLoading = _machine.loadState == InboxLoadState.loading;
  }

  void _notify() => _onStateChanged();
}

class _LiveInboxEffects implements InboxEffects {
  _LiveInboxEffects._(this._coordinator);

  final InboxCoordinator _coordinator;

  InboxCoordinator get _c => _coordinator;

  @override
  Future<void> loadInbox({
    required int generation,
    required bool showLoadingIndicator,
  }) async {
    if (!_c.enableInboxLoads) return;

    if (showLoadingIndicator) {
      _c.state.error = null;
      _c._syncLoadingFromMachine();
      _c._notify();
    }

    try {
      final loaded = await _c._inboxService
          .fetchInbox()
          .timeout(const Duration(seconds: 30));
      if (generation != _c._machine.currentLoadGeneration) return;
      _c.state.peers = loaded;
      _c.state.error = null;
      await _c._machine.send(const InboxLoaded());
    } on TimeoutException {
      if (generation != _c._machine.currentLoadGeneration) return;
      _c.state.error = 'Timeout caricamento inbox. Riprova.';
      await _c._machine.send(const InboxLoadFailed());
    } catch (e) {
      if (generation != _c._machine.currentLoadGeneration) return;
      _c.state.error = e.toString();
      await _c._machine.send(const InboxLoadFailed());
    } finally {
      if (generation == _c._machine.currentLoadGeneration) {
        _c._syncLoadingFromMachine();
        _c._notify();
      }
    }
  }
}
