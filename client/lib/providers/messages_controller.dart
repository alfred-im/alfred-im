import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/voice_config.dart';
import '../models/message.dart';
import '../models/outbound_queue_item.dart';
import '../services/inbox_service.dart';
import '../services/message_media_service.dart';
import '../services/message_service.dart';
import '../services/outbound_message_queue.dart';
import '../utils/date_format.dart';

class MessagesController extends ChangeNotifier {
  MessagesController({
    required this.userId,
    required this.peerProfileId,
    required this.messageService,
    required this.messageMediaService,
    required this.inboxService,
    this.onMessagesChanged,
    OutboundMessageQueue? outboundQueue,
  }) : _outboundQueue = outboundQueue ?? OutboundMessageQueue() {
    unawaited(_init());
  }

  final String userId;
  final String peerProfileId;
  final Future<void> Function()? onMessagesChanged;
  final MessageService messageService;
  final MessageMediaService messageMediaService;
  final InboxService inboxService;
  final OutboundMessageQueue _outboundQueue;
  final _uuid = const Uuid();

  List<ChatMessage> messages = [];
  bool isLoading = true;
  bool isSending = false;
  String? error;
  RealtimeChannel? _channel;
  Timer? _retryTimer;

  String get _queueKey => peerProfileId;

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
    final index = messages.indexWhere((m) => m.id == message.id);
    if (index >= 0) {
      messages[index] = _withTimeLabel(message);
    } else {
      messages = [...messages, _withTimeLabel(message)];
    }
    notifyListeners();
  }

  ChatMessage _withTimeLabel(ChatMessage message) {
    final at = message.createdAt ?? DateTime.now();
    return message.copyWith(
      timeLabel: formatMessageTime(at),
      createdAt: at,
    );
  }

  Future<void> load() async {
    try {
      final loaded = await messageService.fetchPeerMessages(
        peerProfileId: peerProfileId,
        currentUserId: userId,
      );
      messages = loaded.map(_withTimeLabel).toList();
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> send(String body) async {
    if (body.trim().isEmpty || isSending) return;
    final clientId = _uuid.v4();
    await _sendOptimistic(
      optimistic: ChatMessage(
        id: clientId,
        body: body.trim(),
        timeLabel: formatMessageTime(DateTime.now()),
        isMine: true,
        status: MessageStatus.pending,
        createdAt: DateTime.now(),
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

  Future<void> sendVoice({
    required Uint8List bytes,
    required int durationMs,
  }) async {
    if (bytes.isEmpty || isSending) return;

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
      messages = messages
          .map((m) => m.id == clientId ? _withTimeLabel(saved) : m)
          .toList();
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
      final alreadyVisible = messages.any((message) => message.id == item.clientId);
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
            senderId: userId,
            contentType: _contentTypeForKind(item.kind),
            mediaUrl: item.kind == OutboundContentKind.text
                ? null
                : 'pending://${item.clientId}',
            durationSeconds: item.durationSeconds,
            mediaMime: item.mediaMime,
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
      }

      messages = messages
          .map(
            (message) => message.id == item.clientId
                ? _withTimeLabel(saved)
                : message,
          )
          .toList();
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
