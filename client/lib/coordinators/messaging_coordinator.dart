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
import '../groups/group_peer_author_enrichment.dart';
import '../machines/messaging/conversation_load_machine.dart';
import '../machines/messaging/conversation_message_store.dart';
import '../machines/messaging/messaging_effects.dart';
import '../machines/messaging/messaging_message_list.dart';
import '../machines/messaging/outbound_send_machine.dart';
import '../machines/messaging/realtime_attachment_machine.dart';
import '../models/conversation_scope.dart';
import '../models/message.dart';
import '../models/outbound_queue_item.dart';
import '../services/inbox_service.dart';
import '../services/message_media_service.dart';
import '../services/peer_message_service.dart';
import '../services/outbound_media_cache.dart';
import '../services/outbound_message_queue.dart';
import '../services/profile_service.dart';
import '../utils/conversation_session_access.dart';
import '../utils/date_format.dart';
import '../utils/diagnostic_log.dart';
import '../utils/image_bytes.dart';
import '../utils/message_reactions_merge.dart';
import '../utils/outbound_media_send_helper.dart';
import '../utils/picked_file_bytes.dart';
import '../utils/prepare_image_for_upload.dart';
import '../utils/video_duration.dart';
import '../utils/video_file_extension.dart';

/// Compone le tre macchine messaging — unico ingresso per [MessagesController].
class MessagingCoordinator {
  MessagingCoordinator({
    required ConversationScope scope,
    required ConversationMessageStore messageStore,
    required String userId,
    required String peerProfileId,
    required PeerMessageService peerMessages,
    required MessageMediaService messageMediaService,
    required InboxService inboxService,
    required this.onChanged,
    ProfileService? profileService,
    GroupPeerAuthorEnrichment? groupPeerAuthorEnrichment,
    Future<void> Function()? onMessagesChanged,
    bool Function()? hasValidSession,
    MessageMediaService Function()? resolveMessageMediaService,
    bool Function()? isScopeCommitted,
    OutboundMessageQueue? outboundQueue,
  }) {
    _effects = _LiveMessagingEffects._(
      this,
      scope: scope,
      messageStore: messageStore,
      userId: userId,
      peerProfileId: peerProfileId,
      peerMessages: peerMessages,
      messageMediaService: messageMediaService,
      inboxService: inboxService,
      profileService: profileService,
      groupPeerAuthorEnrichment: groupPeerAuthorEnrichment,
      onMessagesChanged: onMessagesChanged,
      hasValidSession: hasValidSession,
      resolveMessageMediaService: resolveMessageMediaService,
      isScopeCommitted: isScopeCommitted,
      outboundQueue: outboundQueue,
    );
  }

  @visibleForTesting
  MessagingCoordinator.test({
    this.error,
    required MessagingEffects effects,
    required this.onChanged,
  }) {
    _effects = effects;
  }

  String? error;
  final VoidCallback onChanged;
  late final MessagingEffects _effects;

  final ConversationLoadMachine loadMachine = ConversationLoadMachine();
  final OutboundSendMachine sendMachine = OutboundSendMachine();
  final RealtimeAttachmentMachine realtimeMachine = RealtimeAttachmentMachine();

  RealtimeChannel? _channel;

  List<ChatMessage> get messages =>
      _effects.messageStore.snapshotFor(_effects.scope).messages;
  bool get isLoading => loadMachine.state == ConversationLoadState.loading;
  bool get isSending => sendMachine.state == OutboundSendState.sending;
  bool get hasMoreOlder =>
      _effects.messageStore.snapshotFor(_effects.scope).hasMoreOlder;
  bool get isLoadingOlder =>
      _effects.messageStore.snapshotFor(_effects.scope).isLoadingOlder;

  Future<void> init() async {
    await load();
    if (_effects.isDisposed) return;
    await _effects.restoreFailedFromQueue();
    if (_effects.isDisposed) return;
    await _effects.markRead();
    if (_effects.isDisposed) return;
    attachRealtime();
    if (_effects.isDisposed) return;
    _effects.startRetryTimer(() => unawaited(_processRetries()));
    _notify();
  }

  Future<void> reload() async {
    loadMachine.send(const RefreshConversation());
    error = null;
    _effects.messageStore.beginLoad(_effects.scope);
    _notify();
    await load();
  }

  Future<void> loadOlderMessages() async {
    if (!hasMoreOlder || isLoadingOlder || isLoading) return;
    final applied = await _effects.fetchAndPrependOlderMessages();
    if (!applied || _effects.isDisposed) return;
    _notify();
  }

  static const _fetchScopeRetryAttempts = 8;
  static const _fetchScopeRetryDelay = Duration(milliseconds: 50);

  Future<void> load() async {
    final trace = DiagnosticHub.instance.beginTrace(
      DiagnosticFlows.messaging,
      op: DiagnosticOps.loadConversation,
      data: {
        'ownerUserId': _effects.scope.ownerUserId,
        'peerProfileId': _effects.scope.peerProfileId,
      },
    );
    if (!_effects.ensureValidSession()) {
      trace.fail('load.blocked', 'session_invalid');
      loadMachine.send(const ConversationUnavailable());
      _notify();
      return;
    }
    loadMachine.send(const LoadMessages());
    _notify();
    try {
      var applied = false;
      for (var attempt = 0; attempt < _fetchScopeRetryAttempts; attempt++) {
        trace.step('fetch.attempt', data: {'attempt': attempt});
        applied = await _effects.fetchAndSetMessages();
        if (_effects.isDisposed) return;
        if (applied) break;
        if (attempt < _fetchScopeRetryAttempts - 1) {
          await Future<void>.delayed(_fetchScopeRetryDelay);
          if (!_effects.ensureValidSession()) {
            trace.fail('load.blocked', 'session_invalid_retry');
            loadMachine.send(const ConversationUnavailable());
            _notify();
            return;
          }
        }
      }
      if (!applied && !_effects.isDisposed) {
        if (!_effects.isScopeActive) {
          trace.fail('load.blocked', 'scope_inactive');
          return;
        }
        error = conversationSessionExpiredMessage;
        loadMachine.send(const ConversationUnavailable());
        trace.fail('load.blocked', 'fetch_exhausted');
        _notify();
        return;
      }
      error = null;
      loadMachine.send(const ConversationReady());
      trace.end(data: {'messageCount': messages.length});
    } catch (e) {
      error = friendlyMessagingError(e);
      loadMachine.send(const LoadFailed());
      trace.fail('load.fail', e.runtimeType.toString());
    }
    _notify();
  }

  void attachRealtime() {
    if (realtimeMachine.state == RealtimeAttachmentState.attached) {
      return;
    }
    _channel = _effects.attachRealtime(
      _handleRealtimeMessage,
      onReactionFact: _handleReactionFact,
    );
    realtimeMachine.send(const AttachRealtime());
    _notify();
  }

  void detachRealtime() {
    _effects.disposeRealtime(_channel);
    _channel = null;
    realtimeMachine.send(const DetachRealtime());
    _notify();
  }

  void _handleReactionFact(String logicalMessageId) {
    unawaited(_effects.refreshReactionsForLogicalId(logicalMessageId));
  }

  Future<void> applyReaction({
    required String logicalMessageId,
    required String emoji,
  }) =>
      _effects.applyReaction(logicalMessageId: logicalMessageId, emoji: emoji);

  Future<void> withdrawReaction({required String logicalMessageId}) =>
      _effects.withdrawReaction(logicalMessageId: logicalMessageId);

  void _handleRealtimeMessage(ChatMessage message) {
    _effects.messageStore.mutateMessages(
      _effects.scope,
      (messages) => replaceOrInsertMessage(
        messages,
        withTimeLabel(message),
      ),
    );
    if (_effects.hasGroupPeerAuthorEnrichment) {
      unawaited(_effects.enrichAuthorNamesIfNeeded());
    } else {
      _notify();
    }
  }

  Future<void> sendText(String body) async {
    if (body.trim().isEmpty || _guardSend(op: DiagnosticOps.sendText)) return;
    await _effects.sendText(body);
  }

  Future<void> sendGif(Uint8List bytes) async {
    if (bytes.isEmpty || _guardSend(op: DiagnosticOps.sendGif)) return;
    await _effects.sendGif(bytes);
  }

  Future<void> sendImage({required Uint8List bytes, String? caption}) async {
    if (bytes.isEmpty || _guardSend(op: DiagnosticOps.sendImage)) return;
    await _effects.sendImage(bytes: bytes, caption: caption);
  }

  Future<void> sendVideoFromPicker({
    required PlatformFile file,
    String? caption,
  }) async {
    if (_guardSend(notifyOnBusy: true, op: DiagnosticOps.sendVideo)) return;
    await _effects.sendVideoFromPicker(file: file, caption: caption);
  }

  Future<void> sendVideo({
    required Uint8List bytes,
    required String extension,
    required String mime,
    required int durationSeconds,
    String? caption,
  }) async {
    if (_guardSend(notifyOnBusy: true, op: DiagnosticOps.sendVideo)) return;
    await _effects.sendVideo(
      bytes: bytes,
      extension: extension,
      mime: mime,
      durationSeconds: durationSeconds,
      caption: caption,
    );
  }

  Future<void> sendVoice({
    required Uint8List bytes,
    required int durationMs,
  }) async {
    if (bytes.isEmpty || _guardSend(op: DiagnosticOps.sendVoice)) return;
    await _effects.sendVoice(bytes: bytes, durationMs: durationMs);
  }

  Future<void> sendLocation({
    required double latitude,
    required double longitude,
  }) async {
    if (_guardSend(op: DiagnosticOps.sendLocation)) return;
    await _effects.sendLocation(latitude: latitude, longitude: longitude);
  }

  Future<void> retryMessage(String clientId) async {
    if (_guardSend()) return;
    sendMachine.send(const RetryFailedSend());
    _notify();
    var failed = false;
    try {
      await _effects.retryMessage(clientId);
    } catch (_) {
      failed = true;
    } finally {
      notifySendEnded(failed);
    }
  }

  Future<void> _processRetries() async {
    if (isSending) return;
    await _effects.processRetries();
  }

  void notifySendStarted() {
    sendMachine.send(const SendStarted());
    _notify();
  }

  void notifySendEnded(bool failed) {
    DiagnosticHub.instance.emit(
      DiagnosticFlows.messaging,
      failed ? 'send.fail' : 'send.done',
    );
    sendMachine.send(failed ? const ContentSendFailed() : const ContentSent());
    _notify();
  }

  void dispose() {
    detachRealtime();
    if (_effects case final _LiveMessagingEffects live) {
      live.markDisposed();
    }
    _effects.disposeQueue();
  }

  /// `true` when send must be blocked (busy or session expired).
  bool _guardSend({bool notifyOnBusy = false, String? op}) {
    if (isSending) {
      DiagnosticHub.instance.emitFail(
        DiagnosticFlows.messaging,
        'send.guard',
        'send_busy',
        data: {'op': op},
      );
      if (notifyOnBusy) {
        error = 'Invio già in corso, attendi il completamento.';
        _notify();
      }
      return true;
    }
    if (loadMachine.state == ConversationLoadState.sessionBlocked) {
      DiagnosticHub.instance.emitFail(
        DiagnosticFlows.messaging,
        'send.guard',
        'session_blocked',
        data: {
          'op': op,
          'loadState': loadMachine.state.name,
        },
      );
      return true;
    }
    DiagnosticHub.instance.emit(
      DiagnosticFlows.messaging,
      'send.start',
      data: {'op': op},
    );
    return false;
  }

  void _notify() {
    if (_effects.isDisposed) return;
    onChanged();
  }
}

class _LiveMessagingEffects implements MessagingEffects {
  _LiveMessagingEffects._(this._coordinator, {
    required this.scope,
    required this.messageStore,
    required this.userId,
    required this.peerProfileId,
    required this.peerMessages,
    required this.messageMediaService,
    required this.inboxService,
    this.profileService,
    this.groupPeerAuthorEnrichment,
    this.onMessagesChanged,
    this.hasValidSession,
    this.resolveMessageMediaService,
    this.isScopeCommitted,
    OutboundMessageQueue? outboundQueue,
  }) : _outboundQueue = outboundQueue ?? OutboundMessageQueue();
  final MessagingCoordinator _coordinator;

  MessagingCoordinator get _c => _coordinator;

  static const _peerMessagesPageSize = 100;

  @override
  final ConversationScope scope;
  @override
  final ConversationMessageStore messageStore;
  final String userId;
  final String peerProfileId;
  final Future<void> Function()? onMessagesChanged;
  final bool Function()? hasValidSession;
  final MessageMediaService Function()? resolveMessageMediaService;
  final bool Function()? isScopeCommitted;
  final PeerMessageService peerMessages;
  final MessageMediaService messageMediaService;
  final InboxService inboxService;
  final ProfileService? profileService;
  final GroupPeerAuthorEnrichment? groupPeerAuthorEnrichment;
  final OutboundMessageQueue _outboundQueue;

  @override
  bool get hasGroupPeerAuthorEnrichment => groupPeerAuthorEnrichment != null;

  final _uuid = const Uuid();
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

  @override
  bool get isScopeActive => _scopeIsActive();

  List<ChatMessage> get _activeMessages =>
      messageStore.messagesIfActive(scope);

  bool _mutateMessages(List<ChatMessage> Function(List<ChatMessage>) update) =>
      messageStore.mutateMessages(scope, update);

  void _appendOptimistic(ChatMessage optimistic) {
    _mutateMessages((messages) => [...messages, optimistic]);
    _c._notify();
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
    _c._notify();
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
    _c.error = null;
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
    _c.error = error;
  }

  void _endOutboundLifecycle(bool sendFailed) {
    _c.notifySendEnded(sendFailed);
    _c._notify();
  }

  @override
  Future<bool> fetchAndSetMessages() async {
    final gen = ++_fetchGeneration;
    if (!_scopeIsActive()) return false;
    messageStore.beginLoad(scope);
    _c._notify();
    final loaded = await peerMessages.fetchPeerMessages(
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
      await _hydrateReactions(
        await _enrichMessages(loaded.map(withTimeLabel).toList()),
      ),
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
    _c._notify();

    final loaded = await peerMessages.fetchPeerMessages(
      peerProfileId: peerProfileId,
      currentUserId: userId,
      limit: _peerMessagesPageSize,
      beforeCreatedAt: before,
    );

    if (gen != _fetchGeneration || _disposed) return false;
    if (!_scopeIsActive()) return false;

    final enriched = await _hydrateReactions(
      await _enrichMessages(loaded.map(withTimeLabel).toList()),
    );
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
    _c._notify();
  }
  @override Future<void> markRead() => inboxService.markRead(peerProfileId);

  Future<List<ChatMessage>> _hydrateReactions(List<ChatMessage> messages) async {
    final ids = collectLogicalMessageIds(messages);
    if (ids.isEmpty) return messages;
    final summaries = await peerMessages.fetchReactionSummaries(ids);
    return attachReactionsToMessages(messages, summaries);
  }

  @override
  Future<void> refreshReactionsForLogicalId(String logicalMessageId) async {
    if (!_scopeIsActive()) return;
    final summaries =
        await peerMessages.fetchReactionSummaries([logicalMessageId]);
    final reactions = summaries[logicalMessageId] ?? const [];
    _mutateMessages(
      (messages) => messages
          .map(
            (message) => message.logicalMessageId == logicalMessageId
                ? message.copyWith(reactions: reactions)
                : message,
          )
          .toList(),
    );
    _c._notify();
  }

  @override
  Future<void> applyReaction({
    required String logicalMessageId,
    required String emoji,
  }) async {
    if (!_scopeIsActive()) {
      throw StateError(conversationSessionExpiredMessage);
    }
    await peerMessages.applyReaction(
      logicalMessageId: logicalMessageId,
      emoji: emoji,
    );
    await refreshReactionsForLogicalId(logicalMessageId);
  }

  @override
  Future<void> withdrawReaction({required String logicalMessageId}) async {
    if (!_scopeIsActive()) {
      throw StateError(conversationSessionExpiredMessage);
    }
    await peerMessages.withdrawReaction(
      logicalMessageId: logicalMessageId,
    );
    await refreshReactionsForLogicalId(logicalMessageId);
  }

  @override
  RealtimeChannel? attachRealtime(
    void Function(ChatMessage message) onMessage, {
    void Function(String logicalMessageId)? onReactionFact,
  }) {
    return peerMessages.subscribeToPeerMessages(
      currentUserId: userId,
      peerProfileId: peerProfileId,
      onMessage: (message) {
        if (!_scopeIsActive()) return;
        onMessage(message);
      },
      onReactionFact: onReactionFact == null
          ? null
          : (logicalMessageId) {
              if (!_scopeIsActive()) return;
              onReactionFact(logicalMessageId);
            },
    );
  }
  @override void disposeRealtime(RealtimeChannel? channel) => peerMessages.disposeChannel(channel);
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

  OutboundMediaSendHelper _mediaHelper() => OutboundMediaSendHelper(
        mediaService: resolveMessageMediaService?.call() ?? messageMediaService,
        userId: userId,
      );

  void _requireValidSessionForUpload() {
    if (!ensureValidSession()) {
      throw StateError(conversationSessionExpiredMessage);
    }
  }

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
      _c.error = conversationSessionExpiredMessage;
      _c._notify();
      return false;
    }
    if (!_messagingSessionReady()) {
      final client = peerMessages.client;
      final reason = clientHasGoTrueSession(client)
          ? 'identity_mismatch'
          : 'jwt_missing';
      diagLogFail(
        'messaging',
        'session.check',
        reason,
        data: {
          'userId': userId,
          'peerProfileId': peerProfileId,
          'authUserId': client.auth.currentUser?.id,
        },
      );
      _c.error = conversationSessionExpiredMessage;
      _c._notify();
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

  bool _messagingSessionReady() {
    // Produzione: callback legge auth.focusedSession a ogni invio (non il client
    // congelato nel controller — critico dopo picker media / refresh token).
    if (hasValidSession != null) {
      return hasValidSession!();
    }
    return isMessagingSessionReady(
      client: peerMessages.client,
      ownerUserId: userId,
      peerProfileId: peerProfileId,
    );
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
      send: (id) => peerMessages.sendToProfile(
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
        _requireValidSessionForUpload();
        final mediaUrl = await _mediaHelper().uploadGif(bytes);
        return peerMessages.sendGifToProfile(
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
      _c.error = UnsupportedImageFormatException.unsupported().userMessage;
      _c._notify();
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
    _c.notifySendStarted();
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

      _c._notify();

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
    _requireValidSessionForUpload();
    final mediaUrl = await _mediaHelper().uploadNormalizedImage(
      NormalizedImageBytes(bytes: bytes, mime: mime, extension: extension),
    );
    return peerMessages.sendImageToProfile(
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
    _c.notifySendStarted();
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
      _c._notify();

      _requireValidSessionForUpload();
      final mediaUrl = await _mediaHelper().uploadVideo(
        bytes: bytes,
        extension: extension,
        contentType: mime,
      );
      final saved = await peerMessages.sendVideoToProfile(
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
        final mediaUrl = await _mediaHelper().uploadVoice(bytes);
        return peerMessages.sendVoiceToProfile(
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
      send: (id) => peerMessages.sendLocationToProfile(
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
    _c._notify();

    await _dispatchQueueItem(item);
  }

  Future<void> _sendOptimistic({
    required ChatMessage optimistic,
    required OutboundQueueItem queueItem,
    required Future<ChatMessage> Function(String clientId) send,
  }) async {
    await _outboundQueue.enqueue(queueItem);
    _c._notify();

    final clientId = optimistic.id;
    _appendOptimistic(optimistic);

    _c.notifySendStarted();
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
      _c.error = friendlyMessagingError(e);
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
    _c._notify();
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

      _c.notifySendStarted();
      var sendFailed = false;
      try {
        await _dispatchQueueItem(item);
      } catch (_) {
        sendFailed = true;
      } finally {
        _c.notifySendEnded(sendFailed);
      }
      return;
    }
  }

  Future<void> _dispatchQueueItem(OutboundQueueItem item) async {
    _c._notify();

    try {
      if (item.kind != OutboundContentKind.text &&
          item.kind != OutboundContentKind.location) {
        _requireValidSessionForUpload();
      }
      final ChatMessage saved;
      switch (item.kind) {
        case OutboundContentKind.text:
          saved = await peerMessages.sendToProfile(
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
          final mediaUrl = await _mediaHelper().uploadGif(bytes);
          saved = await peerMessages.sendGifToProfile(
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
          final mediaUrl = await _mediaHelper().uploadVoice(bytes);
          saved = await peerMessages.sendVoiceToProfile(
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
          saved = await peerMessages.sendLocationToProfile(
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
          final upload = await _mediaHelper().prepareAndUploadImage(rawBytes);
          final normalized = upload.normalized;
          final mediaUrl = upload.mediaUrl;
          saved = await peerMessages.sendImageToProfile(
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
          final mediaUrl = await _mediaHelper().uploadVideo(
            bytes: bytes,
            extension: extension,
            contentType: mime,
          );
          saved = await peerMessages.sendVideoToProfile(
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
      _c.error = null;
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
      _c.error = friendlyMessagingError(e);
    } finally {
      _c._notify();
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
