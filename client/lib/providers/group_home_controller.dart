// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';

import '../coordinators/group_home_coordinator.dart';
import '../models/chat_peer.dart';
import '../models/group_active_author.dart';
import '../models/profile_summary.dart';
import '../services/account_session.dart';
import '../services/message_service.dart';
import '../services/profile_service.dart';

/// Facade UI home gruppo — orchestrazione in [GroupHomeCoordinator].
class GroupHomeController extends ChangeNotifier {
  GroupHomeController({
    required this.session,
    required this.profile,
    required MessageService messageService,
    required ProfileService profileService,
  }) {
    _coordinator = GroupHomeCoordinator(
      session: session,
      profile: profile,
      messageService: messageService,
      profileService: profileService,
      onStateChanged: notifyListeners,
    );
  }

  final AccountSession session;
  final ProfileSummary profile;
  late final GroupHomeCoordinator _coordinator;

  DateTime? get createdAt => _coordinator.state.createdAt;

  int get totalMessageCount => _coordinator.state.totalMessageCount;

  List<GroupActiveAuthor> get activeAuthors => _coordinator.state.activeAuthors;

  ChatPeer? get conversationTile => _coordinator.state.conversationTile;

  bool get isLoading => _coordinator.state.isLoading;

  String? get error => _coordinator.state.error;

  String get userId => _coordinator.userId;

  Future<void> load() => _coordinator.load();

  Future<void> reload() => _coordinator.reload();

  static String formatBirthDate(DateTime dateTime) =>
      GroupHomeCoordinator.formatBirthDate(dateTime);
}
