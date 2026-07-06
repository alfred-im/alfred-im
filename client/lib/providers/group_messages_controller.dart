import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/message.dart';
import '../models/profile_summary.dart';
import '../services/message_service.dart';
import '../services/profile_service.dart';
import '../utils/author_display.dart' show enrichMessageAuthor;
import '../utils/date_format.dart';

/// Messaggistica account gruppo — storico unico + broadcast allow list.
class GroupMessagesController extends ChangeNotifier {
  GroupMessagesController({
    required this.userId,
    required this.messageService,
    required this.profileService,
    this.onMessagesChanged,
  }) {
    unawaited(_init());
  }

  final String userId;
  final MessageService messageService;
  final ProfileService profileService;
  final Future<void> Function()? onMessagesChanged;

  final _uuid = const Uuid();

  List<ChatMessage> messages = [];
  bool isLoading = true;
  bool isSending = false;
  String? error;
  RealtimeChannel? _channel;

  Future<void> _init() async {
    await load();
    _attachRealtime();
    notifyListeners();
  }

  void _attachRealtime() {
    _channel = messageService.subscribeToOwnerMessages(
      currentUserId: userId,
      onMessage: _handleRealtimeMessage,
    );
  }

  void _handleRealtimeMessage(ChatMessage message) {
    final index = messages.indexWhere((m) => m.id == message.id);
    if (index >= 0) {
      messages[index] = message;
    } else {
      messages.add(message);
      messages.sort(
        (a, b) => (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)),
      );
    }
    unawaited(_enrichAuthorNames());
    notifyListeners();
    unawaited(onMessagesChanged?.call());
  }

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final loaded = await messageService.fetchOwnerMessages(
        currentUserId: userId,
      );
      messages = await _enrichMessages(loaded);
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reload() => load();

  Future<void> send(String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty || isSending) return;

    isSending = true;
    notifyListeners();

    try {
      await messageService.broadcastToAllowlist(
        body: trimmed,
        currentUserId: userId,
        clientMessageId: _uuid.v4(),
      );
      await load();
      await onMessagesChanged?.call();
    } catch (e) {
      error = e.toString();
    } finally {
      isSending = false;
      notifyListeners();
    }
  }

  Future<List<ChatMessage>> _enrichMessages(List<ChatMessage> source) async {
    final authorIds = source
        .map((m) => m.contentAuthorId ?? m.authorId)
        .whereType<String>()
        .where((id) => id != userId)
        .toSet()
        .toList();

    var profilesById = <String, ProfileSummary>{};
    if (authorIds.isNotEmpty) {
      final profiles = await profileService.fetchSummariesByIds(authorIds);
      profilesById = {for (final p in profiles) p.id: p};
    }

    return source
        .map(
          (m) => enrichMessageAuthor(
            message: m,
            profilesById: profilesById,
            currentUserId: userId,
          ).copyWith(
            timeLabel: formatMessageTime(m.createdAt ?? DateTime.now()),
          ),
        )
        .toList();
  }

  Future<void> _enrichAuthorNames() async {
    messages = await _enrichMessages(messages);
  }

  @override
  void dispose() {
    messageService.disposeChannel(_channel);
    super.dispose();
  }
}
