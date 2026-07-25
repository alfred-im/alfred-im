// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../models/message.dart';
import 'group_archive_service.dart';
import 'message_service.dart';

/// Cache sessione per `list_owner_messages` — condivisa tra home e conversazione
/// gruppo per evitare fetch duplicati sullo stesso owner.
class GroupOwnerArchiveCache {
  GroupOwnerArchiveCache({
    required this.groupArchiveService,
    required this.userId,
  });

  static final Map<String, GroupOwnerArchiveCache> _byUserId = {};

  /// Istanza condivisa per [userId] nella sessione corrente.
  static GroupOwnerArchiveCache forUserId({
    required String userId,
    required GroupArchiveService groupArchiveService,
  }) {
    final existing = _byUserId[userId];
    if (existing != null) return existing;
    final cache = GroupOwnerArchiveCache(
      groupArchiveService: groupArchiveService,
      userId: userId,
    );
    _byUserId[userId] = cache;
    return cache;
  }

  /// Retrocompat: estrae [GroupArchiveService] dalla facade [MessageService].
  static GroupOwnerArchiveCache forMessageService({
    required String userId,
    required MessageService messageService,
  }) =>
      forUserId(
        userId: userId,
        groupArchiveService: messageService.groupArchive,
      );

  /// Rimuove la cache quando la sessione account viene smontata.
  static void evict(String userId) => _byUserId.remove(userId);

  final GroupArchiveService groupArchiveService;
  final String userId;

  List<ChatMessage>? _cached;
  Future<List<ChatMessage>>? _inFlight;

  Future<List<ChatMessage>> fetch({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _cached;
      if (cached != null) return List<ChatMessage>.from(cached);
      final inFlight = _inFlight;
      if (inFlight != null) return inFlight;
    } else {
      _cached = null;
    }

    final future = groupArchiveService
        .fetchOwnerMessages(currentUserId: userId)
        .then((messages) {
      _cached = List<ChatMessage>.from(messages);
      return messages;
    });

    _inFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    }
  }

  void replace(List<ChatMessage> messages) {
    _cached = List<ChatMessage>.from(messages);
  }

  void invalidate() => _cached = null;
}
