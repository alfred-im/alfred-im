// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/location_config.dart';
import '../config/voice_config.dart';
import '../config/chat_media_config.dart';
import '../models/message.dart';
import '../models/profile_summary.dart';
import '../models/outbound_queue_item.dart';
import '../services/inbox_service.dart';
import '../services/message_media_service.dart';
import '../services/message_service.dart';
import '../services/outbound_message_queue.dart';
import '../services/profile_service.dart';
import '../utils/author_display.dart' show enrichMessageAuthor;
import '../utils/date_format.dart';
import '../utils/video_duration.dart';

class MessagesController extends ChangeNotifier {
  MessagesController({
    required this.userId,
    required this.peerProfileId,
    required this.messageService,
    required this.messageMediaService,
    required this.inboxService,
    this.profileService,
    this.peerIsGroup = false,
    this.onMessagesChanged,
    this.hasValidSession,
    OutboundMessageQueue? outboundQueue,
  }) : _outboundQueue = outboundQueue ?? OutboundMessageQueue() {
    unawaited(_init());
  }

  static const sessionExpiredMessage = 'Sessione scaduta — accedi di nuovo';

  final String userId;
  final String peerProfileId;
  final Future<void> Function()? onMessagesChanged;
  final bool Function()? hasValidSession;
  final MessageService messageService;
  final MessageMediaService messageMediaService;
  final InboxService inboxService;
  final ProfileService? profileService;
  final bool peerIsGroup;
  final OutboundMessageQueue _outboundQueue;
  final _uuid = const Uuid();

  List<ChatMessage> messages = [];
  bool isLoading = true;
  bool isSending = false;
  String? error;
  RealtimeChannel? _channel;
  Timer? _retryTimer;

  /// Chiave coda retry: account + peer (evita collisioni multi-account).
  static String outboundQueueKey({
    required String userId,
    required String peerProfileId,
  }) =>
      '$userId|$peerProfileId';

  String get _queueKey =>
      outboundQueueKey(userId: userId, peerProfileId: peerProfileId);

  Future<void> _init() async {
    await load();
    await _restoreFailedFromQueue();
    await inboxService.markRead(peerProfileId);
    _attachRealtime();
    _retryTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(_processRetries());
    });
    notifyListeners();
  }

  void _attachRealtime() {
    if (_channel != null) return;
    _channel = messageService.subscribeToPeerMessages(
      currentUserId: userId,
      peerProfileId: peerProfileId,
      onMessage: _handleRealtimeMessage,
    );
  }

  void _handleRealtimeMessage(ChatMessage message) {
    messages = _replaceOrInsertMessage(messages, _withTimeLabel(message));
    if (peerIsGroup) {
      unawaited(_enrichAuthorNames());
    } else {
      notifyListeners();
    }
  }

  int _indexForMessage(List<ChatMessage> list, ChatMessage message) {
    final clientKey = message.clientMessageId;
    for (var i = 0; i < list.length; i++) {
      final existing = list[i];
      if (existing.id == message.id) return i;
      if (clientKey != null &&
          (existing.id == clientKey || existing.clientMessageId == clientKey)) {
        return i;
      }
      final existingClientKey = existing.clientMessageId;
      if (existingClientKey != null && existingClientKey == message.id) {
        return i;
      }
    }
    return -1;
  }

  List<ChatMessage> _replaceOrInsertMessage(
    List<ChatMessage> list,
    ChatMessage message,
  ) {
    final index = _indexForMessage(list, message);
    if (index >= 0) {
      final next = List<ChatMessage>.from(list);
      next[index] = message;
      return next;
    }
    return [...list, message];
  }

  List<ChatMessage> _dedupeMessages(List<ChatMessage> source) {
    final deduped = <ChatMessage>[];
    for (final message in source) {
      final index = _indexForMessage(deduped, message);
      if (index >= 0) {
        deduped[index] = message;
      } else {
        deduped.add(message);
      }
    }
    return deduped;
  }

  ChatMessage _withTimeLabel(ChatMessage message) {
    final at = message.createdAt ?? DateTime.now();
    return message.copyWith(
      timeLabel: formatMessageTime(at),
      createdAt: at,
    );
  }

  Future<void> reload() async {
    isLoading = true;
    error = null;
    notifyListeners();
    await load();
  }

  bool _ensureValidSession() {
    if (hasValidSession != null && !hasValidSession!()) {
      error = sessionExpiredMessage;
      isLoading = false;
      notifyListeners();
      return false;
    }
    return true;
  }

  Future<void> load() async {
    if (!_ensureValidSession()) return;
    try {
      final loaded = await messageService.fetchPeerMessages(
        peerProfileId: peerProfileId,
        currentUserId: userId,
      );
      messages = _dedupeMessages(
        await _enrichMessages(loaded.map(_withTimeLabel).toList()),
      );
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<List<ChatMessage>> _enrichMessages(List<ChatMessage> source) async {
    if (!peerIsGroup || profileService == null) return source;

    final authorIds = source
        .map((m) => m.contentAuthorId ?? m.authorId)
        .whereType<String>()
        .where((id) => id != userId)
        .toSet()
        .toList();

    var profilesById = <String, ProfileSummary>{};
    if (authorIds.isNotEmpty) {
      final profiles = await profileService!.fetchSummariesByIds(authorIds);
      profilesById = {for (final p in profiles) p.id: p};
    }

    return source
        .map(
          (m) => enrichMessageAuthor(
            message: m,
            profilesById: profilesById,
            currentUserId: userId,
          ),
        )
        .toList();
  }

  Future<void> _enrichAuthorNames() async {
    messages = await _enrichMessages(messages);
    notifyListeners();
  }

  Future<void> send(String body) async {
    if (body.trim().isEmpty || isSending) return;
    if (!_ensureValidSession()) return;
    final clientId = _uuid.v4();
    await _sendOptimistic(
      optimistic: ChatMessage(
        id: clientId,
        body: body.trim(),
        timeLabel: formatMessageTime(DateTime.now()),
        isMine: true,
        status: MessageStatus.pending,
        createdAt: DateTime.now(),
        clientMessageId: clientId,
        senderId: userId,
      ),
      queueItem: OutboundQueueItem(
        clientId: clientId,
        queueKey: _queueKey,
        kind: OutboundContentKind.text,
        attempts: 0,
        queuedAt: DateTime.now(),
        body: body.trim(),
      ),
      send: (id) => messageService.sendToProfile(
        recipientProfileId: peerProfileId,
        body: body.trim(),
        currentUserId: userId,
        clientMessageId: id,
      ),
    );
  }

  Future<void> sendGif(Uint8List bytes) async {
    if (bytes.isEmpty || isSending) return;
    if (!_ensureValidSession()) return;
    final clientId = _uuid.v4();
    final mediaPath = await _outboundQueue.persistMediaBytes(
      clientId: clientId,
      bytes: bytes,
      extension: 'gif',
    );

    await _sendOptimistic(
      optimistic: ChatMessage(
        id: clientId,
        body: '',
        timeLabel: formatMessageTime(DateTime.now()),
        isMine: true,
        status: MessageStatus.pending,
        createdAt: DateTime.now(),
        clientMessageId: clientId,
        senderId: userId,
        contentType: MessageContentType.gif,
        mediaUrl: 'pending://$clientId',
        retryPayloadPath: mediaPath,
      ),
      queueItem: OutboundQueueItem(
        clientId: clientId,
        queueKey: _queueKey,
        kind: OutboundContentKind.gif,
        attempts: 0,
        queuedAt: DateTime.now(),
        localMediaPath: mediaPath,
      ),
      send: (id) async {
        final mediaUrl = await messageMediaService.uploadGif(
          bytes: bytes,
          userId: userId,
        );
        return messageService.sendGifToProfile(
          recipientProfileId: peerProfileId,
          mediaUrl: mediaUrl,
          currentUserId: userId,
          clientMessageId: id,
        );
      },
    );
  }

  Future<void> sendImage({
    required Uint8List bytes,
    required String extension,
    required String mime,
    String? caption,
  }) async {
    if (bytes.isEmpty || isSending) return;
    if (!_ensureValidSession()) return;

    final body = caption?.trim() ?? '';
    final clientId = _uuid.v4();
    final mediaPath = await _outboundQueue.persistMediaBytes(
      clientId: clientId,
      bytes: bytes,
      extension: extension,
    );

    await _sendOptimistic(
      optimistic: ChatMessage(
        id: clientId,
        body: body,
        timeLabel: formatMessageTime(DateTime.now()),
        isMine: true,
        status: MessageStatus.pending,
        createdAt: DateTime.now(),
        clientMessageId: clientId,
        senderId: userId,
        contentType: MessageContentType.image,
        mediaUrl: 'pending://$clientId',
        mediaMime: mime,
        mediaSizeBytes: bytes.length,
        retryPayloadPath: mediaPath,
      ),
      queueItem: OutboundQueueItem(
        clientId: clientId,
        queueKey: _queueKey,
        kind: OutboundContentKind.image,
        attempts: 0,
        queuedAt: DateTime.now(),
        body: body.isEmpty ? null : body,
        localMediaPath: mediaPath,
        mediaMime: mime,
        mediaExtension: extension,
      ),
      send: (id) async {
        final mediaUrl = await messageMediaService.uploadImage(
          bytes: bytes,
          userId: userId,
          extension: extension,
          contentType: mime,
        );
        return messageService.sendImageToProfile(
          recipientProfileId: peerProfileId,
          mediaUrl: mediaUrl,
          mediaMime: mime,
          mediaSizeBytes: bytes.length,
          currentUserId: userId,
          clientMessageId: id,
          body: body,
        );
      },
    );
  }

  Future<void> sendVideo({
    required Uint8List bytes,
    required String extension,
    required String mime,
    required int durationSeconds,
    String? caption,
  }) async {
    if (bytes.isEmpty || isSending) return;
    if (!_ensureValidSession()) return;

    final body = caption?.trim() ?? '';
    final clientId = _uuid.v4();
    final mediaPath = await _outboundQueue.persistMediaBytes(
      clientId: clientId,
      bytes: bytes,
      extension: extension,
    );

    await _sendOptimistic(
      optimistic: ChatMessage(
        id: clientId,
        body: body,
        timeLabel: formatMessageTime(DateTime.now()),
        isMine: true,
        status: MessageStatus.pending,
        createdAt: DateTime.now(),
        clientMessageId: clientId,
        senderId: userId,
        contentType: MessageContentType.video,
        mediaUrl: 'pending://$clientId',
        durationSeconds: durationSeconds,
        mediaMime: mime,
        mediaSizeBytes: bytes.length,
        retryPayloadPath: mediaPath,
      ),
      queueItem: OutboundQueueItem(
        clientId: clientId,
        queueKey: _queueKey,
        kind: OutboundContentKind.video,
        attempts: 0,
        queuedAt: DateTime.now(),
        body: body.isEmpty ? null : body,
        localMediaPath: mediaPath,
        durationSeconds: durationSeconds,
        mediaMime: mime,
        mediaExtension: extension,
      ),
      send: (id) async {
        final mediaUrl = await messageMediaService.uploadVideo(
          bytes: bytes,
          userId: userId,
          extension: extension,
          contentType: mime,
        );
        return messageService.sendVideoToProfile(
          recipientProfileId: peerProfileId,
          mediaUrl: mediaUrl,
          mediaMime: mime,
          durationSeconds: durationSeconds,
          mediaSizeBytes: bytes.length,
          currentUserId: userId,
          clientMessageId: id,
          body: body,
        );
      },
    );
  }

  Future<void> sendVoice({
    required Uint8List bytes,
    required int durationMs,
  }) async {
    if (bytes.isEmpty || isSending) return;
    if (!_ensureValidSession()) return;

    final durationSeconds =
        (durationMs / 1000).ceil().clamp(1, VoiceConfig.maxDurationSeconds);
    final clientId = _uuid.v4();
    final mediaPath = await _outboundQueue.persistMediaBytes(
      clientId: clientId,
      bytes: bytes,
      extension: VoiceConfig.fileExtension,
    );

    await _sendOptimistic(
      optimistic: ChatMessage(
        id: clientId,
        body: '',
        timeLabel: formatMessageTime(DateTime.now()),
        isMine: true,
        status: MessageStatus.pending,
        createdAt: DateTime.now(),
        clientMessageId: clientId,
        senderId: userId,
        contentType: MessageContentType.voice,
        mediaUrl: 'pending://$clientId',
        durationSeconds: durationSeconds,
        mediaMime: VoiceConfig.canonicalMime,
        mediaSizeBytes: bytes.length,
        retryPayloadPath: mediaPath,
      ),
      queueItem: OutboundQueueItem(
        clientId: clientId,
        queueKey: _queueKey,
        kind: OutboundContentKind.voice,
        attempts: 0,
        queuedAt: DateTime.now(),
        localMediaPath: mediaPath,
        durationSeconds: durationSeconds,
        mediaMime: VoiceConfig.canonicalMime,
      ),
      send: (id) async {
        final mediaUrl = await messageMediaService.uploadVoice(
          bytes: bytes,
          userId: userId,
        );
        return messageService.sendVoiceToProfile(
          recipientProfileId: peerProfileId,
          mediaUrl: mediaUrl,
          durationSeconds: durationSeconds,
          mediaSizeBytes: bytes.length,
          currentUserId: userId,
          clientMessageId: id,
        );
      },
    );
  }

  Future<void> sendLocation({
    required double latitude,
    required double longitude,
  }) async {
    if (isSending) return;
    if (!_ensureValidSession()) return;

    final lat = LocationConfig.roundCoordinate(latitude);
    final lng = LocationConfig.roundCoordinate(longitude);
    final clientId = _uuid.v4();

    await _sendOptimistic(
      optimistic: ChatMessage(
        id: clientId,
        body: '',
        timeLabel: formatMessageTime(DateTime.now()),
        isMine: true,
        status: MessageStatus.pending,
        createdAt: DateTime.now(),
        clientMessageId: clientId,
        senderId: userId,
        contentType: MessageContentType.location,
        latitude: lat,
        longitude: lng,
      ),
      queueItem: OutboundQueueItem(
        clientId: clientId,
        queueKey: _queueKey,
        kind: OutboundContentKind.location,
        attempts: 0,
        queuedAt: DateTime.now(),
        latitude: lat,
        longitude: lng,
      ),
      send: (id) => messageService.sendLocationToProfile(
        recipientProfileId: peerProfileId,
        latitude: lat,
        longitude: lng,
        currentUserId: userId,
        clientMessageId: id,
      ),
    );
  }

  Future<void> retryMessage(String clientId) async {
    final item = (await _outboundQueue.loadForQueueKey(_queueKey))
        .where((entry) => entry.clientId == clientId)
        .firstOrNull;
    if (item == null) return;

    messages = messages
        .map(
          (message) => message.id == clientId
              ? message.copyWith(status: MessageStatus.pending)
              : message,
        )
        .toList();
    notifyListeners();

    await _dispatchQueueItem(item);
  }

  Future<void> _sendOptimistic({
    required ChatMessage optimistic,
    required OutboundQueueItem queueItem,
    required Future<ChatMessage> Function(String clientId) send,
  }) async {
    isSending = true;
    await _outboundQueue.enqueue(queueItem);
    notifyListeners();

    final clientId = optimistic.id;
    messages = [...messages, optimistic];
    notifyListeners();

    try {
      final saved = await send(clientId);
      messages = _replaceOrInsertMessage(messages, _withTimeLabel(saved));
      await _outboundQueue.remove(clientId);
      await _outboundQueue.deleteMediaFile(
        queueItem.localMediaPath,
        clientId: clientId,
      );
      error = null;
      if (onMessagesChanged != null) {
        await onMessagesChanged!();
      }
    } catch (e) {
      final failedItem = queueItem.copyWith(
        attempts: queueItem.attempts + 1,
        lastError: e.toString(),
      );
      await _outboundQueue.update(failedItem);
      messages = messages
          .map(
            (m) => m.id == clientId
                ? m.copyWith(
                    status: MessageStatus.failed,
                    isMine: true,
                    retryPayloadPath: queueItem.localMediaPath,
                  )
                : m,
          )
          .toList();
      error = e.toString();
    } finally {
      isSending = false;
      notifyListeners();
    }
  }

  Future<void> _restoreFailedFromQueue() async {
    final queued = await _outboundQueue.loadForQueueKey(_queueKey);
    if (queued.isEmpty) return;

    for (final item in queued) {
      final alreadyVisible = messages.any(
        (message) =>
            message.id == item.clientId ||
            message.clientMessageId == item.clientId,
      );
      if (alreadyVisible) continue;

      messages = [
        ...messages,
        _withTimeLabel(
          ChatMessage(
            id: item.clientId,
            body: item.body ?? '',
            timeLabel: formatMessageTime(item.queuedAt),
            isMine: true,
            status: MessageStatus.failed,
            createdAt: item.queuedAt,
            clientMessageId: item.clientId,
            senderId: userId,
            contentType: _contentTypeForKind(item.kind),
            mediaUrl: item.kind == OutboundContentKind.text
                ? null
                : 'pending://${item.clientId}',
            durationSeconds: item.durationSeconds,
            mediaMime: item.mediaMime,
            latitude: item.latitude,
            longitude: item.longitude,
            retryPayloadPath: item.localMediaPath,
          ),
        ),
      ];
    }
    notifyListeners();
  }

  MessageContentType _contentTypeForKind(OutboundContentKind kind) {
    switch (kind) {
      case OutboundContentKind.gif:
        return MessageContentType.gif;
      case OutboundContentKind.voice:
        return MessageContentType.voice;
      case OutboundContentKind.location:
        return MessageContentType.location;
      case OutboundContentKind.image:
        return MessageContentType.image;
      case OutboundContentKind.video:
        return MessageContentType.video;
      case OutboundContentKind.text:
        return MessageContentType.text;
    }
  }

  Future<void> _processRetries() async {
    if (isSending) return;
    final queued = await _outboundQueue.loadForQueueKey(_queueKey);
    for (final item in queued) {
      final delay = _outboundQueue.retryDelayForAttempts(item.attempts);
      if (DateTime.now().difference(item.queuedAt) < delay) continue;
      await _dispatchQueueItem(item);
    }
  }

  Future<void> _dispatchQueueItem(OutboundQueueItem item) async {
    if (isSending) return;
    isSending = true;
    notifyListeners();

    try {
      final ChatMessage saved;
      switch (item.kind) {
        case OutboundContentKind.text:
          saved = await messageService.sendToProfile(
            recipientProfileId: peerProfileId,
            body: item.body ?? '',
            currentUserId: userId,
            clientMessageId: item.clientId,
          );
        case OutboundContentKind.gif:
          final bytes = await _outboundQueue.readMediaBytes(
            item.localMediaPath,
            item.clientId,
          );
          if (bytes == null || bytes.isEmpty) {
            throw StateError('GIF retry payload missing');
          }
          final mediaUrl = await messageMediaService.uploadGif(
            bytes: bytes,
            userId: userId,
          );
          saved = await messageService.sendGifToProfile(
            recipientProfileId: peerProfileId,
            mediaUrl: mediaUrl,
            currentUserId: userId,
            clientMessageId: item.clientId,
          );
        case OutboundContentKind.voice:
          final bytes = await _outboundQueue.readMediaBytes(
            item.localMediaPath,
            item.clientId,
          );
          if (bytes == null || bytes.isEmpty) {
            throw StateError('Voice retry payload missing');
          }
          final durationSeconds = item.durationSeconds ??
              (bytes.length / 16000).ceil().clamp(1, VoiceConfig.maxDurationSeconds);
          final mediaUrl = await messageMediaService.uploadVoice(
            bytes: bytes,
            userId: userId,
          );
          saved = await messageService.sendVoiceToProfile(
            recipientProfileId: peerProfileId,
            mediaUrl: mediaUrl,
            durationSeconds: durationSeconds,
            mediaSizeBytes: bytes.length,
            currentUserId: userId,
            clientMessageId: item.clientId,
          );
        case OutboundContentKind.location:
          final latitude = item.latitude;
          final longitude = item.longitude;
          if (latitude == null || longitude == null) {
            throw StateError('Location retry payload missing');
          }
          saved = await messageService.sendLocationToProfile(
            recipientProfileId: peerProfileId,
            latitude: latitude,
            longitude: longitude,
            currentUserId: userId,
            clientMessageId: item.clientId,
          );
        case OutboundContentKind.image:
          final bytes = await _outboundQueue.readMediaBytes(
            item.localMediaPath,
            item.clientId,
          );
          if (bytes == null || bytes.isEmpty) {
            throw StateError('Image retry payload missing');
          }
          final extension = item.mediaExtension ?? 'jpg';
          final mime = item.mediaMime ??
              ChatMediaConfig.imageMimeForExtension(extension) ??
              'image/jpeg';
          final mediaUrl = await messageMediaService.uploadImage(
            bytes: bytes,
            userId: userId,
            extension: extension,
            contentType: mime,
          );
          saved = await messageService.sendImageToProfile(
            recipientProfileId: peerProfileId,
            mediaUrl: mediaUrl,
            mediaMime: mime,
            mediaSizeBytes: bytes.length,
            currentUserId: userId,
            clientMessageId: item.clientId,
            body: item.body ?? '',
          );
        case OutboundContentKind.video:
          final bytes = await _outboundQueue.readMediaBytes(
            item.localMediaPath,
            item.clientId,
          );
          if (bytes == null || bytes.isEmpty) {
            throw StateError('Video retry payload missing');
          }
          final extension = item.mediaExtension ?? 'mp4';
          final mime = item.mediaMime ??
              ChatMediaConfig.videoMimeForExtension(extension) ??
              'video/mp4';
          final durationSeconds = item.durationSeconds ??
              await readVideoDurationSeconds(bytes: bytes, extension: extension);
          final mediaUrl = await messageMediaService.uploadVideo(
            bytes: bytes,
            userId: userId,
            extension: extension,
            contentType: mime,
          );
          saved = await messageService.sendVideoToProfile(
            recipientProfileId: peerProfileId,
            mediaUrl: mediaUrl,
            mediaMime: mime,
            durationSeconds: durationSeconds,
            mediaSizeBytes: bytes.length,
            currentUserId: userId,
            clientMessageId: item.clientId,
            body: item.body ?? '',
          );
      }

      messages = _replaceOrInsertMessage(messages, _withTimeLabel(saved));
      await _outboundQueue.remove(item.clientId);
      await _outboundQueue.deleteMediaFile(
        item.localMediaPath,
        clientId: item.clientId,
      );
      error = null;
      if (onMessagesChanged != null) {
        await onMessagesChanged!();
      }
    } catch (e) {
      await _outboundQueue.update(
        item.copyWith(attempts: item.attempts + 1, lastError: e.toString()),
      );
      messages = messages
          .map(
            (message) => message.id == item.clientId
                ? message.copyWith(status: MessageStatus.failed)
                : message,
          )
          .toList();
      error = e.toString();
    } finally {
      isSending = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    messageService.disposeChannel(_channel);
    _outboundQueue.dispose();
    super.dispose();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
