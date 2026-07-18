// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/chat_media_config.dart';
import '../config/location_config.dart';
import '../config/voice_config.dart';
import '../machines/groups/groups_machine.dart';
import '../models/message.dart';
import '../models/profile_summary.dart';
import '../services/message_media_service.dart';
import '../services/message_service.dart';
import '../services/profile_service.dart';
import '../utils/author_display.dart' show enrichMessageAuthor;
import '../utils/date_format.dart';
import '../utils/merge_chat_message.dart';
import '../utils/prepare_image_for_upload.dart';
import '../utils/picked_file_bytes.dart';
import '../utils/video_duration.dart';
import '../utils/video_file_extension.dart';

/// Stato conversazione gruppo esposto alla UI tramite [GroupMessagesController].
class GroupMessagesUiState {
  List<ChatMessage> messages = [];
  bool isLoading = true;
  bool isSending = false;
  String? error;
}

/// Orchestrazione storico owner, broadcast e realtime gruppo.
class GroupMessagesCoordinator {
  GroupMessagesCoordinator({
    required this._userId,
    required this._messageService,
    required this._messageMediaService,
    required this._profileService,
    required this._onStateChanged,
    this.onMessagesChanged,
  }) {
    _machine = GroupMessagesMachine(_LiveGroupMessagesEffects._(this));
    unawaited(_machine.send(const InitGroupMessages()));
  }

  final String _userId;
  final MessageService _messageService;
  final MessageMediaService _messageMediaService;
  final ProfileService _profileService;
  final void Function() _onStateChanged;
  final Future<void> Function()? onMessagesChanged;
  late final GroupMessagesMachine _machine;
  final GroupMessagesUiState state = GroupMessagesUiState();
  final _uuid = const Uuid();

  RealtimeChannel? _channel;
  Future<ChatMessage> Function(String clientId)? _pendingBroadcast;

  GroupMessagesMachine get machine => _machine;

  Future<void> load() => _machine.send(const LoadGroupMessages());

  Future<void> reload() => load();

  Future<void> send(String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty || state.isSending) return;
    await _broadcast(
      (clientId) => _messageService.broadcastToAllowlist(
        body: trimmed,
        currentUserId: _userId,
        clientMessageId: clientId,
      ),
    );
  }

  Future<void> sendGif(Uint8List bytes) async {
    if (bytes.isEmpty || state.isSending) return;
    await _broadcast((clientId) async {
      final mediaUrl = await _messageMediaService.uploadGif(
        bytes: bytes,
        userId: _userId,
      );
      return _messageService.broadcastGifToAllowlist(
        mediaUrl: mediaUrl,
        currentUserId: _userId,
        clientMessageId: clientId,
      );
    });
  }

  Future<void> sendVoice({
    required Uint8List bytes,
    required int durationMs,
  }) async {
    if (bytes.isEmpty || state.isSending) return;
    final durationSeconds =
        (durationMs / 1000).ceil().clamp(1, VoiceConfig.maxDurationSeconds);
    await _broadcast((clientId) async {
      final mediaUrl = await _messageMediaService.uploadVoice(
        bytes: bytes,
        userId: _userId,
      );
      return _messageService.broadcastVoiceToAllowlist(
        mediaUrl: mediaUrl,
        durationSeconds: durationSeconds,
        mediaSizeBytes: bytes.length,
        currentUserId: _userId,
        clientMessageId: clientId,
      );
    });
  }

  Future<void> sendImage({
    required Uint8List bytes,
    String? caption,
  }) async {
    if (bytes.isEmpty || state.isSending) return;
    final body = caption?.trim() ?? '';
    await _broadcast((clientId) async {
      final normalized = await prepareImageForUpload(bytes);
      final mediaUrl = await _messageMediaService.uploadImage(
        bytes: normalized.bytes,
        userId: _userId,
        extension: normalized.extension,
        contentType: normalized.mime,
      );
      return _messageService.broadcastImageToAllowlist(
        mediaUrl: mediaUrl,
        mediaMime: normalized.mime,
        mediaSizeBytes: normalized.bytes.length,
        currentUserId: _userId,
        clientMessageId: clientId,
        body: body,
      );
    });
  }

  Future<void> sendVideoFromPicker({
    required PlatformFile file,
    String? caption,
  }) async {
    final extension = videoExtensionFromPickedFile(file);
    if (!isSupportedVideoExtension(extension)) return;

    final bytes = await readPickedFileBytes(file);
    if (bytes == null || bytes.isEmpty) return;

    final mime =
        ChatMediaConfig.videoMimeForExtension(extension) ?? 'video/mp4';
    final durationSeconds = await readVideoDurationSeconds(
      bytes: bytes,
      extension: extension,
    );

    await sendVideo(
      bytes: bytes,
      extension: extension,
      mime: mime,
      durationSeconds: durationSeconds,
      caption: caption,
    );
  }

  Future<void> sendVideo({
    required Uint8List bytes,
    required String extension,
    required String mime,
    required int durationSeconds,
    String? caption,
  }) async {
    if (bytes.isEmpty || state.isSending) return;
    final body = caption?.trim() ?? '';
    await _broadcast((clientId) async {
      final mediaUrl = await _messageMediaService.uploadVideo(
        bytes: bytes,
        userId: _userId,
        extension: extension,
        contentType: mime,
      );
      return _messageService.broadcastVideoToAllowlist(
        mediaUrl: mediaUrl,
        mediaMime: mime,
        durationSeconds: durationSeconds,
        mediaSizeBytes: bytes.length,
        currentUserId: _userId,
        clientMessageId: clientId,
        body: body,
      );
    });
  }

  Future<void> sendLocation({
    required double latitude,
    required double longitude,
  }) async {
    if (state.isSending) return;
    final lat = LocationConfig.roundCoordinate(latitude);
    final lng = LocationConfig.roundCoordinate(longitude);
    await _broadcast(
      (clientId) => _messageService.broadcastLocationToAllowlist(
        latitude: lat,
        longitude: lng,
        currentUserId: _userId,
        clientMessageId: clientId,
      ),
    );
  }

  Future<void> _broadcast(
    Future<ChatMessage> Function(String clientId) send,
  ) async {
    _pendingBroadcast = send;
    await _machine.send(const BroadcastRequested());
  }

  void dispose() {
    unawaited(_machine.send(const DisposeGroupMessages()));
  }

  void _syncFromMachine() {
    state.isLoading = _machine.loadState == GroupMessagesLoadState.loading;
    state.isSending = _machine.broadcastState == GroupBroadcastState.sending;
  }

  void _notify() => _onStateChanged();
}

class _LiveGroupMessagesEffects implements GroupMessagesEffects {
  _LiveGroupMessagesEffects._(this._coordinator);

  final GroupMessagesCoordinator _coordinator;

  GroupMessagesCoordinator get _c => _coordinator;

  @override
  Future<void> loadMessages() async {
    try {
      final loaded = await _c._messageService.fetchOwnerMessages(
        currentUserId: _c._userId,
      );
      _c.state.messages = await _enrichMessages(loaded);
      _c.state.error = null;
      await _c._machine.send(const GroupMessagesLoaded());
    } catch (e) {
      _c.state.error = e.toString();
      await _c._machine.send(const GroupMessagesLoadFailed());
    } finally {
      _c._syncFromMachine();
      _c._notify();
    }
  }

  @override
  void attachRealtime() {
    if (_c._channel != null) return;
    _c._channel = _c._messageService.subscribeToOwnerMessages(
      currentUserId: _c._userId,
      onMessage: (message) {
        unawaited(_c._machine.send(OwnerRealtimeReceived(message)));
      },
    );
  }

  @override
  void disposeRealtime() {
    _c._messageService.disposeChannel(_c._channel);
    _c._channel = null;
  }

  @override
  Future<void> runBroadcast() async {
    final send = _c._pendingBroadcast;
    if (send == null) {
      await _c._machine.send(const BroadcastFailed());
      _c._syncFromMachine();
      _c._notify();
      return;
    }
    _c._pendingBroadcast = null;
    try {
      await send(_c._uuid.v4());
      await loadMessages();
      await _c.onMessagesChanged?.call();
      _c.state.error = null;
      await _c._machine.send(const BroadcastAcknowledged());
    } catch (e) {
      _c.state.error = e.toString();
      await _c._machine.send(const BroadcastFailed());
    } finally {
      _c._syncFromMachine();
      _c._notify();
    }
  }

  @override
  void onRealtimeMessage(ChatMessage message) {
    final index = _c.state.messages.indexWhere((m) => m.id == message.id);
    if (index >= 0) {
      _c.state.messages[index] = mergeChatMessage(
        existing: _c.state.messages[index],
        incoming: message,
      );
    } else {
      _c.state.messages.add(message);
      _c.state.messages.sort(
        (a, b) =>
            (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)),
      );
    }
    unawaited(_enrichAuthorNames());
    _c._notify();
    unawaited(_c.onMessagesChanged?.call());
  }

  Future<List<ChatMessage>> _enrichMessages(List<ChatMessage> source) async {
    final authorIds = source
        .map((m) => m.contentAuthorId ?? m.authorId)
        .whereType<String>()
        .where((id) => id != _c._userId)
        .toSet()
        .toList();

    var profilesById = <String, ProfileSummary>{};
    if (authorIds.isNotEmpty) {
      final profiles = await _c._profileService.fetchSummariesByIds(authorIds);
      profilesById = {for (final p in profiles) p.id: p};
    }

    return source
        .map(
          (m) => enrichMessageAuthor(
            message: m,
            profilesById: profilesById,
            currentUserId: _c._userId,
          ).copyWith(
            timeLabel: formatMessageTime(m.createdAt ?? DateTime.now()),
          ),
        )
        .toList();
  }

  Future<void> _enrichAuthorNames() async {
    _c.state.messages = await _enrichMessages(_c.state.messages);
  }
}
