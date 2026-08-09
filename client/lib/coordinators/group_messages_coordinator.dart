// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/chat_media_config.dart';
import '../config/location_config.dart';
import '../config/voice_config.dart';
import '../machines/groups/groups_effects.dart';
import '../machines/groups/groups_machine.dart';
import '../models/message.dart';
import '../models/profile_summary.dart';
import '../services/group_owner_archive_cache.dart';
import '../services/group_archive_service.dart';
import '../services/message_media_service.dart';
import '../services/profile_service.dart';
import '../utils/author_display.dart' show enrichMessageAuthor;
import '../utils/date_format.dart';
import '../utils/merge_chat_message.dart';
import '../utils/outbound_media_send_helper.dart';
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

typedef _GroupBroadcastSend = Future<ChatMessage> Function(String clientId);

class _GroupMediaBroadcastSpec {
  const _GroupMediaBroadcastSpec({
    required this.isReady,
    required this.send,
  });

  final bool Function() isReady;
  final _GroupBroadcastSend send;
}

/// Orchestrazione storico owner, broadcast e realtime gruppo.
class GroupMessagesCoordinator {
  GroupMessagesCoordinator({
    required String userId,
    required GroupArchiveService groupArchive,
    required MessageMediaService messageMediaService,
    required ProfileService profileService,
    required GroupOwnerArchiveCache ownerArchiveCache,
    required void Function() onStateChanged,
    this.onMessagesChanged,
  })  : _userId = userId,
        _groupArchive = groupArchive,
        _messageMediaService = messageMediaService,
        _profileService = profileService,
        _ownerArchiveCache = ownerArchiveCache,
        _onStateChanged = onStateChanged {
    _machine = GroupMessagesMachine(_LiveGroupMessagesEffects._(this));
    unawaited(_machine.send(const InitGroupMessages()));
  }

  final String _userId;
  final GroupArchiveService _groupArchive;
  final MessageMediaService _messageMediaService;
  final ProfileService _profileService;
  final GroupOwnerArchiveCache _ownerArchiveCache;
  final void Function() _onStateChanged;
  final Future<void> Function()? onMessagesChanged;
  late final GroupMessagesMachine _machine;
  final GroupMessagesUiState state = GroupMessagesUiState();
  final _uuid = const Uuid();
  final Map<String, ProfileSummary> _knownAuthorProfiles = {};

  RealtimeChannel? _channel;
  Future<ChatMessage> Function(String clientId)? _pendingBroadcast;

  OutboundMediaSendHelper get _mediaHelper => OutboundMediaSendHelper(
        mediaService: _messageMediaService,
        userId: _userId,
      );

  GroupMessagesMachine get machine => _machine;

  Future<void> load() => _machine.send(const LoadGroupMessages());

  Future<void> reload() => load();

  Future<void> send(String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty || state.isSending) return;
    await _broadcast(
      (clientId) => _groupArchive.broadcastToAllowlist(
        body: trimmed,
        currentUserId: _userId,
        clientMessageId: clientId,
      ),
    );
  }

  Future<void> sendGif(Uint8List bytes) => _runMediaBroadcast(
        _GroupMediaBroadcastSpec(
          isReady: () => bytes.isNotEmpty && !state.isSending,
          send: (clientId) async {
            final mediaUrl = await _mediaHelper.uploadGif(bytes);
            return _groupArchive.broadcastGifToAllowlist(
              mediaUrl: mediaUrl,
              currentUserId: _userId,
              clientMessageId: clientId,
            );
          },
        ),
      );

  Future<void> sendVoice({
    required Uint8List bytes,
    required int durationMs,
  }) {
    final durationSeconds =
        (durationMs / 1000).ceil().clamp(1, VoiceConfig.maxDurationSeconds);
    return _runMediaBroadcast(
      _GroupMediaBroadcastSpec(
        isReady: () => bytes.isNotEmpty && !state.isSending,
        send: (clientId) async {
          final mediaUrl = await _mediaHelper.uploadVoice(bytes);
          return _groupArchive.broadcastVoiceToAllowlist(
            mediaUrl: mediaUrl,
            durationSeconds: durationSeconds,
            mediaSizeBytes: bytes.length,
            currentUserId: _userId,
            clientMessageId: clientId,
          );
        },
      ),
    );
  }

  Future<void> sendImage({
    required Uint8List bytes,
    String? caption,
  }) {
    final body = caption?.trim() ?? '';
    return _runMediaBroadcast(
      _GroupMediaBroadcastSpec(
        isReady: () => bytes.isNotEmpty && !state.isSending,
        send: (clientId) async {
          final upload = await _mediaHelper.prepareAndUploadImage(bytes);
          return _groupArchive.broadcastImageToAllowlist(
            mediaUrl: upload.mediaUrl,
            mediaMime: upload.normalized.mime,
            mediaSizeBytes: upload.normalized.bytes.length,
            currentUserId: _userId,
            clientMessageId: clientId,
            body: body,
          );
        },
      ),
    );
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
  }) {
    final body = caption?.trim() ?? '';
    return _runMediaBroadcast(
      _GroupMediaBroadcastSpec(
        isReady: () => bytes.isNotEmpty && !state.isSending,
        send: (clientId) async {
          final mediaUrl = await _mediaHelper.uploadVideo(
            bytes: bytes,
            extension: extension,
            contentType: mime,
          );
          return _groupArchive.broadcastVideoToAllowlist(
            mediaUrl: mediaUrl,
            mediaMime: mime,
            durationSeconds: durationSeconds,
            mediaSizeBytes: bytes.length,
            currentUserId: _userId,
            clientMessageId: clientId,
            body: body,
          );
        },
      ),
    );
  }

  Future<void> sendLocation({
    required double latitude,
    required double longitude,
  }) async {
    if (state.isSending) return;
    final lat = LocationConfig.roundCoordinate(latitude);
    final lng = LocationConfig.roundCoordinate(longitude);
    await _broadcast(
      (clientId) => _groupArchive.broadcastLocationToAllowlist(
        latitude: lat,
        longitude: lng,
        currentUserId: _userId,
        clientMessageId: clientId,
      ),
    );
  }

  Future<void> _runMediaBroadcast(_GroupMediaBroadcastSpec spec) async {
    if (!spec.isReady()) return;
    await _broadcast(spec.send);
  }

  Future<void> _broadcast(_GroupBroadcastSend send) async {
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
  Future<void> loadMessages({bool forceRefresh = false}) async {
    try {
      final loaded = await _c._ownerArchiveCache.fetch(
        forceRefresh: forceRefresh,
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
    _c._channel = _c._groupArchive.subscribeToOwnerMessages(
      currentUserId: _c._userId,
      onMessage: (message) {
        unawaited(_c._machine.send(OwnerRealtimeReceived(message)));
      },
    );
  }

  @override
  void disposeRealtime() {
    _c._groupArchive.disposeChannel(_c._channel);
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
      _c._ownerArchiveCache.invalidate();
      await loadMessages(forceRefresh: true);
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
    final merged = index >= 0
        ? mergeChatMessage(
            existing: _c.state.messages[index],
            incoming: message,
          )
        : message;

    if (index >= 0) {
      _c.state.messages[index] = merged;
    } else {
      _c.state.messages.add(merged);
      _c.state.messages.sort(
        (a, b) =>
            (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)),
      );
    }
    unawaited(_enrichRealtimeMessage(merged));
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

    if (authorIds.isNotEmpty) {
      final missingIds = authorIds
          .where((id) => !_c._knownAuthorProfiles.containsKey(id))
          .toList();
      if (missingIds.isNotEmpty) {
        final profiles =
            await _c._profileService.fetchSummariesByIds(missingIds);
        for (final profile in profiles) {
          _c._knownAuthorProfiles[profile.id] = profile;
        }
      }
    }

    return source
        .map(
          (m) => enrichMessageAuthor(
            message: m,
            profilesById: _c._knownAuthorProfiles,
            currentUserId: _c._userId,
          ).copyWith(
            timeLabel: formatMessageTime(m.createdAt ?? DateTime.now()),
          ),
        )
        .toList();
  }

  Future<void> _enrichRealtimeMessage(ChatMessage message) async {
    final enriched = await _enrichSingleMessage(message);
    final index = _c.state.messages.indexWhere((m) => m.id == enriched.id);
    if (index < 0) return;
    _c.state.messages[index] = enriched;
    _c._notify();
  }

  Future<ChatMessage> _enrichSingleMessage(ChatMessage message) async {
    final authorId = message.contentAuthorId ?? message.authorId;
    if (authorId != null &&
        authorId != _c._userId &&
        !_c._knownAuthorProfiles.containsKey(authorId)) {
      final profiles =
          await _c._profileService.fetchSummariesByIds([authorId]);
      for (final profile in profiles) {
        _c._knownAuthorProfiles[profile.id] = profile;
      }
    }

    return enrichMessageAuthor(
      message: message,
      profilesById: _c._knownAuthorProfiles,
      currentUserId: _c._userId,
    ).copyWith(
      timeLabel: formatMessageTime(message.createdAt ?? DateTime.now()),
    );
  }
}
