// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/location_config.dart';
import '../config/voice_config.dart';
import '../models/message.dart';
import '../models/profile_summary.dart';
import '../services/message_media_service.dart';
import '../services/message_service.dart';
import '../services/profile_service.dart';
import '../utils/author_display.dart' show enrichMessageAuthor;
import '../utils/date_format.dart';
import '../utils/merge_chat_message.dart';
import '../utils/prepare_image_for_upload.dart';

/// Messaggistica account gruppo — storico unico + broadcast allow list.
class GroupMessagesController extends ChangeNotifier {
  GroupMessagesController({
    required this.userId,
    required this.messageService,
    required this.messageMediaService,
    required this.profileService,
    this.onMessagesChanged,
  }) {
    unawaited(_init());
  }

  final String userId;
  final MessageService messageService;
  final MessageMediaService messageMediaService;
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
      messages[index] = mergeChatMessage(
        existing: messages[index],
        incoming: message,
      );
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

    await _broadcast(
      (clientId) => messageService.broadcastToAllowlist(
        body: trimmed,
        currentUserId: userId,
        clientMessageId: clientId,
      ),
    );
  }

  Future<void> sendGif(Uint8List bytes) async {
    if (bytes.isEmpty || isSending) return;

    await _broadcast((clientId) async {
      final mediaUrl = await messageMediaService.uploadGif(
        bytes: bytes,
        userId: userId,
      );
      return messageService.broadcastGifToAllowlist(
        mediaUrl: mediaUrl,
        currentUserId: userId,
        clientMessageId: clientId,
      );
    });
  }

  Future<void> sendVoice({
    required Uint8List bytes,
    required int durationMs,
  }) async {
    if (bytes.isEmpty || isSending) return;

    final durationSeconds =
        (durationMs / 1000).ceil().clamp(1, VoiceConfig.maxDurationSeconds);

    await _broadcast((clientId) async {
      final mediaUrl = await messageMediaService.uploadVoice(
        bytes: bytes,
        userId: userId,
      );
      return messageService.broadcastVoiceToAllowlist(
        mediaUrl: mediaUrl,
        durationSeconds: durationSeconds,
        mediaSizeBytes: bytes.length,
        currentUserId: userId,
        clientMessageId: clientId,
      );
    });
  }

  Future<void> sendImage({
    required Uint8List bytes,
    String? caption,
  }) async {
    if (bytes.isEmpty || isSending) return;

    final body = caption?.trim() ?? '';

    await _broadcast((clientId) async {
      final normalized = await prepareImageForUpload(bytes);
      final mediaUrl = await messageMediaService.uploadImage(
        bytes: normalized.bytes,
        userId: userId,
        extension: normalized.extension,
        contentType: normalized.mime,
      );
      return messageService.broadcastImageToAllowlist(
        mediaUrl: mediaUrl,
        mediaMime: normalized.mime,
        mediaSizeBytes: normalized.bytes.length,
        currentUserId: userId,
        clientMessageId: clientId,
        body: body,
      );
    });
  }

  Future<void> sendVideo({
    required Uint8List bytes,
    required String extension,
    required String mime,
    required int durationSeconds,
    String? caption,
  }) async {
    if (bytes.isEmpty || isSending) return;

    final body = caption?.trim() ?? '';

    await _broadcast((clientId) async {
      final mediaUrl = await messageMediaService.uploadVideo(
        bytes: bytes,
        userId: userId,
        extension: extension,
        contentType: mime,
      );
      return messageService.broadcastVideoToAllowlist(
        mediaUrl: mediaUrl,
        mediaMime: mime,
        durationSeconds: durationSeconds,
        mediaSizeBytes: bytes.length,
        currentUserId: userId,
        clientMessageId: clientId,
        body: body,
      );
    });
  }

  Future<void> sendLocation({
    required double latitude,
    required double longitude,
  }) async {
    if (isSending) return;

    final lat = LocationConfig.roundCoordinate(latitude);
    final lng = LocationConfig.roundCoordinate(longitude);

    await _broadcast(
      (clientId) => messageService.broadcastLocationToAllowlist(
        latitude: lat,
        longitude: lng,
        currentUserId: userId,
        clientMessageId: clientId,
      ),
    );
  }

  Future<void> _broadcast(
    Future<ChatMessage> Function(String clientId) send,
  ) async {
    isSending = true;
    notifyListeners();

    try {
      await send(_uuid.v4());
      await load();
      await onMessagesChanged?.call();
      error = null;
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
