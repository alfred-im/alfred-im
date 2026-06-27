import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/voice_config.dart';
import '../models/message.dart';
import '../models/outbound_queue_item.dart';
import '../services/conversation_service.dart';
import '../services/message_media_service.dart';
import '../services/message_service.dart';
import '../services/outbound_message_queue.dart';
import '../services/supabase_bootstrap.dart';
import '../utils/date_format.dart';

class MessagesController extends ChangeNotifier {
  MessagesController({
    required this.conversationId,
    required this.userId,
    MessageService? messageService,
    MessageMediaService? messageMediaService,
    ConversationService? conversationService,
    OutboundMessageQueue? outboundQueue,
  })  : _messageService = messageService ?? MessageService(),
        _messageMediaService = messageMediaService ?? const MessageMediaService(),
        _conversationService = conversationService ?? ConversationService(),
        _outboundQueue = outboundQueue ?? OutboundMessageQueue() {
    _init();
  }

  final String conversationId;
  final String userId;
  final MessageService _messageService;
  final MessageMediaService _messageMediaService;
  final ConversationService _conversationService;
  final OutboundMessageQueue _outboundQueue;
  final _uuid = const Uuid();

  List<ChatMessage> messages = [];
  bool isLoading = true;
  bool isSending = false;
  String? error;
  RealtimeChannel? _channel;
  Timer? _retryTimer;

  Future<void> _init() async {
    await load();
    await _restoreFailedFromQueue();
    await _conversationService.markRead(conversationId);
    _channel = _messageService.subscribeToMessages(
      conversationId: conversationId,
      currentUserId: userId,
      onMessage: _handleRealtimeMessage,
    );
    _retryTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(_processRetries());
    });
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
      final loaded = await _messageService.fetchMessages(
        conversationId: conversationId,
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
        conversationId: conversationId,
        kind: OutboundContentKind.text,
        attempts: 0,
        queuedAt: DateTime.now(),
        body: body.trim(),
      ),
      send: (id) => _messageService.sendMessage(
        conversationId: conversationId,
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
        conversationId: conversationId,
        kind: OutboundContentKind.gif,
        attempts: 0,
        queuedAt: DateTime.now(),
        localMediaPath: mediaPath,
      ),
      send: (id) async {
        final mediaUrl = await _messageMediaService.uploadGif(
          bytes: bytes,
          userId: userId,
        );
        return _messageService.sendGif(
          conversationId: conversationId,
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

    final durationSeconds = (durationMs / 1000).ceil().clamp(1, VoiceConfig.maxDurationSeconds);
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
        conversationId: conversationId,
        kind: OutboundContentKind.voice,
        attempts: 0,
        queuedAt: DateTime.now(),
        localMediaPath: mediaPath,
        durationSeconds: durationSeconds,
        mediaMime: VoiceConfig.canonicalMime,
      ),
      send: (id) async {
        final mediaUrl = await _messageMediaService.uploadVoice(
          bytes: bytes,
          userId: userId,
        );
        return _messageService.sendVoice(
          conversationId: conversationId,
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
    final item = (await _outboundQueue.loadForConversation(conversationId))
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
    final queued = await _outboundQueue.loadForConversation(conversationId);
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
    final queued = await _outboundQueue.loadForConversation(conversationId);
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
          saved = await _messageService.sendMessage(
            conversationId: conversationId,
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
          final mediaUrl = await _messageMediaService.uploadGif(
            bytes: bytes,
            userId: userId,
          );
          saved = await _messageService.sendGif(
            conversationId: conversationId,
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
          final mediaUrl = await _messageMediaService.uploadVoice(
            bytes: bytes,
            userId: userId,
          );
          saved = await _messageService.sendVoice(
            conversationId: conversationId,
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
    disposeRealtimeChannel(_channel);
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
