// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';

import '../coordinators/inbox_coordinator.dart';
import '../models/chat_peer.dart';
import '../services/inbox_service.dart';

/// Facade UI inbox — orchestrazione in [InboxCoordinator].
class InboxController extends ChangeNotifier {
  InboxController({
    required this.userId,
    required InboxService inboxService,
    this.enableRealtime = true,
    this.enableInboxLoads = true,
  }) {
    _coordinator = InboxCoordinator(
      userId: userId,
      inboxService: inboxService,
      onStateChanged: notifyListeners,
      enableRealtime: enableRealtime,
      enableInboxLoads: enableInboxLoads,
    );
  }

  final String userId;
  final bool enableRealtime;
  final bool enableInboxLoads;
  late final InboxCoordinator _coordinator;

  List<ChatPeer> get peers => _coordinator.state.peers;

  bool get isLoading => _coordinator.state.isLoading;

  String? get error => _coordinator.state.error;

  List<ChatPeer> get filteredPeers => _coordinator.filteredPeers;

  void setSearchQuery(String value) => _coordinator.setSearchQuery(value);

  ChatPeer? findByProfileId(String profileId) =>
      _coordinator.findByProfileId(profileId);

  Future<void> load({bool showLoadingIndicator = true}) =>
      _coordinator.load(showLoadingIndicator: showLoadingIndicator);

  @override
  void dispose() {
    _coordinator.dispose();
    super.dispose();
  }
}
