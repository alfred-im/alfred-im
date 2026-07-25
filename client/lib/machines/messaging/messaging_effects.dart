// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../config/chat_media_config.dart';
import '../../config/location_config.dart';
import '../../config/voice_config.dart';
import '../../models/conversation_scope.dart';
import '../../models/message.dart';
import '../../models/outbound_queue_item.dart';
import '../../groups/group_peer_author_enrichment.dart';
import '../../services/inbox_service.dart';
import '../../services/message_media_service.dart';
import '../../services/message_service.dart';
import '../../services/outbound_media_cache.dart';
import '../../services/outbound_message_queue.dart';
import '../../services/profile_service.dart';
import '../../utils/date_format.dart';
import '../../utils/image_bytes.dart';
import '../../utils/picked_file_bytes.dart';
import '../../utils/prepare_image_for_upload.dart';
import '../../utils/diagnostic_log.dart';
import '../../utils/video_duration.dart';
import '../../utils/video_file_extension.dart';
import 'conversation_message_store.dart';
import 'messaging_conversation_state.dart';
import 'messaging_message_list.dart';

abstract class MessagingEffects {
  ConversationScope get scope;
  ConversationMessageStore get messageStore;
  bool get isDisposed;
  bool ensureValidSession();
  /// Carica messaggi; `false` se scope non più attivo (il coordinator può ritentare).
  Future<bool> fetchAndSetMessages();
  /// Carica pagina più vecchia; `false` se scope non più attivo.
  Future<bool> fetchAndPrependOlderMessages();
  Future<void> enrichAuthorNamesIfNeeded();
  bool get hasGroupPeerAuthorEnrichment;
  Future<void> markRead();
  RealtimeChannel? attachRealtime(void Function(ChatMessage message) onMessage);
  void disposeRealtime(RealtimeChannel? channel);
  void startRetryTimer(void Function() onTick);
  void stopRetryTimer();
  Future<void> restoreFailedFromQueue();
  Future<void> sendText(String body);
  Future<void> sendGif(Uint8List bytes);
  Future<void> sendImage({required Uint8List bytes, String? caption});
  Future<void> sendVideoFromPicker({required PlatformFile file, String? caption});
  Future<void> sendVideo({required Uint8List bytes, required String extension, required String mime, required int durationSeconds, String? caption});
  Future<void> sendVoice({required Uint8List bytes, required int durationMs});
  Future<void> sendLocation({required double latitude, required double longitude});
  Future<void> retryMessage(String clientId);
  Future<void> processRetries();
  void disposeQueue();
}

class MessagesControllerEffects implements MessagingEffects {
  MessagesControllerEffects({
    required this._state,
    required this.scope,
    required this.messageStore,
    required this.userId,
    required this.peerProfileId,
    required this.messageService,
    required this.messageMediaService,
    required this.inboxService,
    this.profileService,
    this.groupPeerAuthorEnrichment,
    this.onMessagesChanged,
    this.hasValidSession,
    this.isScopeCommitted,
    OutboundMessageQueue? outboundQueue,
    required this._onChanged,
  }) : _outboundQueue = outboundQueue ?? OutboundMessageQueue();
  static const sessionExpiredMessage = 'Sessione scaduta — accedi di nuovo';
  static const _peerMessagesPageSize = 100;

  @override
  final ConversationScope scope;
  @override
  final ConversationMessageStore messageStore;
  final String userId;
  final String peerProfileId;
  final Future<void> Function()? onMessagesChanged;
  final bool Function()? hasValidSession;
  final bool Function()? isScopeCommitted;
  final MessageService messageService;
  final MessageMediaService messageMediaService;
  final InboxService inboxService;
  final ProfileService? profileService;
  final GroupPeerAuthorEnrichment? groupPeerAuthorEnrichment;
  final OutboundMessageQueue _outboundQueue;

  @override
  bool get hasGroupPeerAuthorEnrichment => groupPeerAuthorEnrichment != null;
  final MessagingConversationState _state;
  final VoidCallback _onChanged;
  final _uuid = const Uuid();
  void Function()? onSendLifecycleStart;
  void Function(bool failed)? onSendLifecycleEnd;
  Timer? _retryTimer;
  int _fetchGeneration = 0;
  bool _disposed = false;

  @override
  bool get isDisposed => _disposed;

  void markDisposed() {
    _disposed = true;
    _fetchGeneration++;
    stopRetryTimer();
  }

  bool _scopeIsActive() {
    if (_disposed) return false;
    if (isScopeCommitted == null) return false;
    return isScopeCommitted!();
  }

  List<ChatMessage> get _activeMessages =>
      messageStore.messagesIfActive(scope);

  bool _mutateMessages(List<ChatMessage> Function(List<ChatMessage>) update) =>
      messageStore.mutateMessages(scope, update);

  void _appendOptimistic(ChatMessage optimistic) {
    _mutateMessages((messages) => [...messages, optimistic]);
    _onChanged();
  }

  void _patchOutboundMessage(
    String clientId,
    ChatMessage Function(ChatMessage current) patch,
  ) {
    _mutateMessages(
      (messages) => messages
          .map((m) => m.id == clientId ? patch(m) : m)
          .toList(),
    );
    _onChanged();
  }

  Future<void> _finalizeOutboundSuccess({
    required String clientId,
    required ChatMessage saved,
    String? mediaPath,
  }) async {
    _mutateMessages(
      (messages) => replaceOrInsertMessage(messages, withTimeLabel(saved)),
    );
    await _outboundQueue.remove(clientId);
    await _outboundQueue.deleteMediaFile(mediaPath, clientId: clientId);
    _state.error = null;
    if (onMessagesChanged != null) {
      await onMessagesChanged!();
    }
  }

  Future<void> _finalizeOutboundFailed({
    required String clientId,
    required OutboundQueueItem failedItem,
    String? mediaPath,
    required String error,
  }) async {
    await _outboundQueue.enqueue(failedItem);
    _patchOutboundMessage(
      clientId,
      (m) => m.copyWith(
        status: MessageStatus.failed,
        isMine: true,
        retryPayloadPath: mediaPath,
      ),
    );
    _state.error = error;
  }

  void _endOutboundLifecycle(bool sendFailed) {
    onSendLifecycleEnd?.call(sendFailed);
    _onChanged();
  }

  @override
  Future<bool> fetchAndSetMessages() async {
    final gen = ++_fetchGeneration;
    if (!_scopeIsActive()) return false;
    messageStore.beginLoad(scope);
    _onChanged();
    final loaded = await messageService.fetchPeerMessages(
      peerProfileId: peerProfileId,
      currentUserId: userId,
      limit: _peerMessagesPageSize,
    );
    if (gen != _fetchGeneration || _disposed) return false;
    if (!_scopeIsActive()) {
      diagLogFail(
        'messaging',
        'fetch',
        'scope_inactive',
        data: {'userId': userId, 'peerProfileId': peerProfileId},
      );
      return false;
    }
    final enriched = dedupeMessages(
      await _enrichMessages(loaded.map(withTimeLabel).toList()),
    );
    return messageStore.applyLoadedMessages(
      scope,
      enriched,
      hasMoreOlder: loaded.length >= _peerMessagesPageSize,
    );
  }

  @override
  Future<bool> fetchAndPrependOlderMessages() async {
    final snapshot = messageStore.snapshotFor(scope);
    if (!snapshot.hasMoreOlder ||
        snapshot.isLoadingOlder ||
        snapshot.messages.isEmpty) {
      return true;
    }
    final oldest = snapshot.messages.firstWhere(
      (m) => m.createdAt != null,
      orElse: () => snapshot.messages.first,
    );
    final before = oldest.createdAt;
    if (before == null) {
      messageStore.mutateMessages(
        scope,
        (messages) => messages,
      );
      return true;
    }

    final gen = _fetchGeneration;
    messageStore.setLoadingOlder(scope, true);
    _onChanged();

    final loaded = await messageService.fetchPeerMessages(
      peerProfileId: peerProfileId,
      currentUserId: userId,
      limit: _peerMessagesPageSize,
      beforeCreatedAt: before,
    );

    if (gen != _fetchGeneration || _disposed) return false;
    if (!_scopeIsActive()) return false;

    final enriched = await _enrichMessages(loaded.map(withTimeLabel).toList());
    final merged = prependOlderMessages(
      existing: snapshot.messages,
      older: enriched,
    );
    return messageStore.applyLoadedMessages(
      scope,
      merged,
      hasMoreOlder: loaded.length >= _peerMessagesPageSize,
    );
  }

  @override Future<void> enrichAuthorNamesIfNeeded() async {
    final snapshot = messageStore.snapshotFor(scope);
    final enriched = await _enrichMessages(snapshot.messages);
    messageStore.applyLoadedMessages(
      scope,
      enriched,
      hasMoreOlder: snapshot.hasMoreOlder,
    );
    _onChanged();
  }
  @override Future<void> markRead() => inboxService.markRead(peerProfileId);
  @override
  RealtimeChannel? attachRealtime(void Function(ChatMessage message) onMessage) {
    return messageService.subscribeToPeerMessages(
      currentUserId: userId,
      peerProfileId: peerProfileId,
      onMessage: (message) {
        if (!_scopeIsActive()) return;
        onMessage(message);
      },
    );
  }
  @override void disposeRealtime(RealtimeChannel? channel) => messageService.disposeChannel(channel);
  @override void startRetryTimer(void Function() onTick) {
    if (_disposed) return;
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_disposed) return;
      onTick();
    });
  }
  @override void stopRetryTimer() { _retryTimer?.cancel(); _retryTimer = null; }
  @override void disposeQueue() { stopRetryTimer(); _outboundQueue.dispose(); }

  String get _queueKey => '$userId|$peerProfileId';

  @override
  bool ensureValidSession() {
    if (!_scopeIsActive()) {
      diagLogFail(
        'messaging',
        'session.check',
        'scope_inactive',
        data: {
          'userId': userId,
          'peerProfileId': peerProfileId,
        },
      );
      _state.error = sessionExpiredMessage;
      _onChanged();
      return false;
    }
    if (hasValidSession != null && !hasValidSession!()) {
      diagLogFail(
        'messaging',
        'session.check',
        'jwt_missing',
        data: {
          'userId': userId,
          'peerProfileId': peerProfileId,
        },
      );
      _state.error = sessionExpiredMessage;
      _onChanged();
      return false;
    }
    diagLog(
      'messaging',
      'session.check',
      data: {
        'userId': userId,
        'peerProfileId': peerProfileId,
        'ok': true,
      },
    );
    return true;
  }

  Future<List<ChatMessage>> _enrichMessages(List<ChatMessage> source) async {
    final enricher = groupPeerAuthorEnrichment;
    if (enricher == null) return source;
    return enricher.enrichMessages(source);
  }

  @override
  Future<void> sendText(String body) async {
    if (body.trim().isEmpty) return;
    if (!ensureValidSession()) return;
    final clientId = _uuid.v4();
    await _sendOptimistic(
      optimistic: pendingOutboundMessage(
        clientId: clientId,
        senderId: userId,
        body: body.trim(),
        contentType: MessageContentType.text,
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

  @override
  Future<void> sendGif(Uint8List bytes) async {
    if (bytes.isEmpty) return;
    if (!ensureValidSession()) return;
    final clientId = _uuid.v4();
    final mediaPath = await _outboundQueue.persistMediaBytes(
      clientId: clientId,
      bytes: bytes,
      extension: 'gif',
    );

    await _sendOptimistic(
      optimistic: pendingOutboundMessage(
        clientId: clientId,
        senderId: userId,
        contentType: MessageContentType.gif,
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

  @override
  Future<void> sendImage({
    required Uint8List bytes,
    String? caption,
  }) async {
    if (bytes.isEmpty) return;
    if (!ensureValidSession()) return;

    final rawFormat = detectImageFormat(bytes);
    if (rawFormat == DetectedImageFormat.unknown) {
      _state.error = UnsupportedImageFormatException.unsupported().userMessage;
      _onChanged();
      return;
    }

    final body = caption?.trim() ?? '';
    final clientId = _uuid.v4();
    final rawExtension = extensionForDetectedFormat(rawFormat);

    // Preview in chat immediately — conversion and disk persist run after.
    OutboundMediaCache.instance.put(clientId, bytes);

    final optimistic = pendingOutboundMessage(
      clientId: clientId,
      senderId: userId,
      body: body,
      contentType: MessageContentType.image,
      mediaMime: ChatMediaConfig.imageMimeForExtension(rawExtension),
      mediaSizeBytes: bytes.length,
    );

    _appendOptimistic(optimistic);
    onSendLifecycleStart?.call();
    var sendFailed = false;
    String? mediaPath;
    try {
      mediaPath = await _outboundQueue.persistMediaBytes(
        clientId: clientId,
        bytes: bytes,
        extension: rawExtension,
      );
      _patchOutboundMessage(
        clientId,
        (m) => m.copyWith(retryPayloadPath: mediaPath),
      );

      final normalized = await prepareImageForUpload(bytes);

      var uploadPath = mediaPath;
      if (normalized.bytes.length != bytes.length ||
          normalized.extension != rawExtension) {
        await _outboundQueue.deleteMediaFile(mediaPath, clientId: clientId);
        uploadPath = await _outboundQueue.persistMediaBytes(
          clientId: clientId,
          bytes: normalized.bytes,
          extension: normalized.extension,
        );
      }

      final queueItem = OutboundQueueItem(
        clientId: clientId,
        queueKey: _queueKey,
        kind: OutboundContentKind.image,
        attempts: 0,
        queuedAt: DateTime.now(),
        body: body.isEmpty ? null : body,
        localMediaPath: uploadPath,
        mediaMime: normalized.mime,
        mediaExtension: normalized.extension,
      );
      await _outboundQueue.enqueue(queueItem);

      _onChanged();

      final saved = await _uploadAndSendImage(
        clientId: clientId,
        bytes: normalized.bytes,
        extension: normalized.extension,
        mime: normalized.mime,
        body: body,
      );
      await _finalizeOutboundSuccess(
        clientId: clientId,
        saved: saved,
        mediaPath: uploadPath,
      );
    } catch (e) {
      final failedItem = OutboundQueueItem(
        clientId: clientId,
        queueKey: _queueKey,
        kind: OutboundContentKind.image,
        attempts: 1,
        queuedAt: DateTime.now(),
        body: body.isEmpty ? null : body,
        localMediaPath: mediaPath,
        lastError: e.toString(),
      );
      await _finalizeOutboundFailed(
        clientId: clientId,
        failedItem: failedItem,
        mediaPath: mediaPath,
        error: e is UnsupportedImageFormatException
            ? e.userMessage
            : e.toString(),
      );
      sendFailed = true;
    } finally {
      _endOutboundLifecycle(sendFailed);
    }
  }

  Future<ChatMessage> _uploadAndSendImage({
    required String clientId,
    required Uint8List bytes,
    required String extension,
    required String mime,
    required String body,
  }) async {
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
      clientMessageId: clientId,
      body: body,
    );
  }

  @override
  Future<void> sendVideoFromPicker({
    required PlatformFile file,
    String? caption,
  }) async {
    final extension = videoExtensionFromPickedFile(file);
    final mime =
        ChatMediaConfig.videoMimeForExtension(extension) ?? 'video/mp4';
    await _sendVideo(
      readBytes: () => readPickedFileBytes(file),
      extension: extension,
      mime: mime,
      caption: caption,
    );
  }

  @override
  Future<void> sendVideo({
    required Uint8List bytes,
    required String extension,
    required String mime,
    required int durationSeconds,
    String? caption,
  }) async {
    await _sendVideo(
      readBytes: () async => bytes,
      extension: extension,
      mime: mime,
      caption: caption,
      initialDurationSeconds: durationSeconds,
    );
  }

  Future<void> _sendVideo({
    required Future<Uint8List?> Function() readBytes,
    required String extension,
    required String mime,
    String? caption,
    int initialDurationSeconds = 1,
  }) async {
    if (!ensureValidSession()) return;

    final body = caption?.trim() ?? '';
    final clientId = _uuid.v4();

    var resolvedDuration = initialDurationSeconds.clamp(
      1,
      ChatMediaConfig.maxVideoDurationSeconds,
    );

    final optimistic = pendingOutboundMessage(
      clientId: clientId,
      senderId: userId,
      body: body,
      contentType: MessageContentType.video,
      durationSeconds: resolvedDuration,
      mediaMime: mime,
    );

    _appendOptimistic(optimistic);
    onSendLifecycleStart?.call();
    var sendFailed = false;
    String? mediaPath;
    try {
      final bytes = await readBytes();
      if (bytes == null || bytes.isEmpty) {
        throw StateError('Impossibile leggere il video selezionato');
      }

      OutboundMediaCache.instance.put(clientId, bytes);
      _patchOutboundMessage(
        clientId,
        (m) => m.copyWith(mediaSizeBytes: bytes.length),
      );

      final probed = await readVideoDurationSeconds(
        bytes: bytes,
        extension: extension,
      );
      resolvedDuration = probed.clamp(1, ChatMediaConfig.maxVideoDurationSeconds);
      _patchOutboundMessage(
        clientId,
        (m) => m.copyWith(durationSeconds: resolvedDuration),
      );

      mediaPath = await _outboundQueue.persistMediaBytes(
        clientId: clientId,
        bytes: bytes,
        extension: extension,
      );
      _patchOutboundMessage(
        clientId,
        (m) => m.copyWith(retryPayloadPath: mediaPath),
      );

      final queueItem = OutboundQueueItem(
        clientId: clientId,
        queueKey: _queueKey,
        kind: OutboundContentKind.video,
        attempts: 0,
        queuedAt: DateTime.now(),
        body: body.isEmpty ? null : body,
        localMediaPath: mediaPath,
        durationSeconds: resolvedDuration,
        mediaMime: mime,
        mediaExtension: extension,
      );
      await _outboundQueue.enqueue(queueItem);
      _onChanged();

      final mediaUrl = await messageMediaService.uploadVideo(
        bytes: bytes,
        userId: userId,
        extension: extension,
        contentType: mime,
      );
      final saved = await messageService.sendVideoToProfile(
        recipientProfileId: peerProfileId,
        mediaUrl: mediaUrl,
        mediaMime: mime,
        durationSeconds: resolvedDuration,
        mediaSizeBytes: bytes.length,
        currentUserId: userId,
        clientMessageId: clientId,
        body: body,
      );
      await _finalizeOutboundSuccess(
        clientId: clientId,
        saved: saved,
        mediaPath: mediaPath,
      );
    } catch (e) {
      final failedItem = OutboundQueueItem(
        clientId: clientId,
        queueKey: _queueKey,
        kind: OutboundContentKind.video,
        attempts: 1,
        queuedAt: DateTime.now(),
        body: body.isEmpty ? null : body,
        localMediaPath: mediaPath,
        durationSeconds: resolvedDuration,
        mediaMime: mime,
        mediaExtension: extension,
        lastError: e.toString(),
      );
      await _finalizeOutboundFailed(
        clientId: clientId,
        failedItem: failedItem,
        mediaPath: mediaPath,
        error: e.toString(),
      );
      sendFailed = true;
    } finally {
      _endOutboundLifecycle(sendFailed);
    }
  }

  @override
  Future<void> sendVoice({
    required Uint8List bytes,
    required int durationMs,
  }) async {
    if (bytes.isEmpty) return;
    if (!ensureValidSession()) return;

    final durationSeconds =
        (durationMs / 1000).ceil().clamp(1, VoiceConfig.maxDurationSeconds);
    final clientId = _uuid.v4();
    final mediaPath = await _outboundQueue.persistMediaBytes(
      clientId: clientId,
      bytes: bytes,
      extension: VoiceConfig.fileExtension,
    );

    await _sendOptimistic(
      optimistic: pendingOutboundMessage(
        clientId: clientId,
        senderId: userId,
        contentType: MessageContentType.voice,
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

  @override
  Future<void> sendLocation({
    required double latitude,
    required double longitude,
  }) async {
    if (!ensureValidSession()) return;

    final lat = LocationConfig.roundCoordinate(latitude);
    final lng = LocationConfig.roundCoordinate(longitude);
    final clientId = _uuid.v4();

    await _sendOptimistic(
      optimistic: pendingOutboundMessage(
        clientId: clientId,
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

  @override
  Future<void> retryMessage(String clientId) async {
    final item = (await _outboundQueue.loadForQueueKey(_queueKey))
        .where((entry) => entry.clientId == clientId)
        .firstOrNull;
    if (item == null) return;

    _mutateMessages((messages) => messages
        .map(
          (message) => message.id == clientId
              ? message.copyWith(status: MessageStatus.pending)
              : message,
        )
        .toList());
    _onChanged();

    await _dispatchQueueItem(item);
  }

  Future<void> _sendOptimistic({
    required ChatMessage optimistic,
    required OutboundQueueItem queueItem,
    required Future<ChatMessage> Function(String clientId) send,
  }) async {
    await _outboundQueue.enqueue(queueItem);
    _onChanged();

    final clientId = optimistic.id;
    _appendOptimistic(optimistic);

    onSendLifecycleStart?.call();
    var sendFailed = false;
    try {
      final saved = await send(clientId);
      await _finalizeOutboundSuccess(
        clientId: clientId,
        saved: saved,
        mediaPath: queueItem.localMediaPath,
      );
    } catch (e) {
      sendFailed = true;
      final failedItem = queueItem.copyWith(
        attempts: queueItem.attempts + 1,
        lastError: e.toString(),
      );
      await _outboundQueue.update(failedItem);
      _patchOutboundMessage(
        clientId,
        (m) => m.copyWith(
          status: MessageStatus.failed,
          isMine: true,
          retryPayloadPath: queueItem.localMediaPath,
        ),
      );
      _state.error = e.toString();
    } finally {
      _endOutboundLifecycle(sendFailed);
    }
  }

  @override
  Future<void> restoreFailedFromQueue() async {
    final queued = await _outboundQueue.loadForQueueKey(_queueKey);
    if (queued.isEmpty) return;

    for (final item in queued) {
      final alreadyVisible = _activeMessages.any(
        (message) =>
            message.id == item.clientId ||
            message.clientMessageId == item.clientId,
      );
      if (alreadyVisible) continue;

      _mutateMessages((messages) => [
        ...messages,
        withTimeLabel(
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
      ]);
    }
    _onChanged();
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

  @override
  Future<void> processRetries() async {
    final queued = await _outboundQueue.loadForQueueKey(_queueKey);
    for (final item in queued) {
      final delay = _outboundQueue.retryDelayForAttempts(item.attempts);
      if (DateTime.now().difference(item.queuedAt) < delay) continue;

      onSendLifecycleStart?.call();
      var sendFailed = false;
      try {
        await _dispatchQueueItem(item);
      } catch (_) {
        sendFailed = true;
      } finally {
        onSendLifecycleEnd?.call(sendFailed);
      }
      return;
    }
  }

  Future<void> _dispatchQueueItem(OutboundQueueItem item) async {
    _onChanged();

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
          final rawBytes = await _outboundQueue.readMediaBytes(
            item.localMediaPath,
            item.clientId,
          );
          if (rawBytes == null || rawBytes.isEmpty) {
            throw StateError('Image retry payload missing');
          }
          final normalized = await prepareImageForUpload(rawBytes);
          final mediaUrl = await messageMediaService.uploadImage(
            bytes: normalized.bytes,
            userId: userId,
            extension: normalized.extension,
            contentType: normalized.mime,
          );
          saved = await messageService.sendImageToProfile(
            recipientProfileId: peerProfileId,
            mediaUrl: mediaUrl,
            mediaMime: normalized.mime,
            mediaSizeBytes: normalized.bytes.length,
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

      _mutateMessages((messages) => replaceOrInsertMessage(messages, withTimeLabel(saved)));
      await _outboundQueue.remove(item.clientId);
      await _outboundQueue.deleteMediaFile(
        item.localMediaPath,
        clientId: item.clientId,
      );
      _state.error = null;
      if (onMessagesChanged != null) {
        await onMessagesChanged!();
      }
    } catch (e) {
      await _outboundQueue.update(
        item.copyWith(attempts: item.attempts + 1, lastError: e.toString()),
      );
      _mutateMessages((messages) => messages
          .map(
            (message) => message.id == item.clientId
                ? message.copyWith(status: MessageStatus.failed)
                : message,
          )
          .toList());
      _state.error = e.toString();
    } finally {
      _onChanged();
    }
  }

}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
