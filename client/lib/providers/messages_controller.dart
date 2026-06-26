import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/message.dart';
import '../services/conversation_service.dart';
import '../services/message_media_service.dart';
import '../services/message_service.dart';
import '../services/supabase_bootstrap.dart';
import '../utils/date_format.dart';

class MessagesController extends ChangeNotifier {
  MessagesController({
    required this.conversationId,
    required this.userId,
    MessageService? messageService,
    MessageMediaService? messageMediaService,
    ConversationService? conversationService,
  })  : _messageService = messageService ?? MessageService(),
        _messageMediaService = messageMediaService ?? const MessageMediaService(),
        _conversationService = conversationService ?? ConversationService() {
    _init();
  }

  final String conversationId;
  final String userId;
  final MessageService _messageService;
  final MessageMediaService _messageMediaService;
  final ConversationService _conversationService;
  final _uuid = const Uuid();

  List<ChatMessage> messages = [];
  bool isLoading = true;
  bool isSending = false;
  String? error;
  RealtimeChannel? _channel;

  Future<void> _init() async {
    await load();
    await _conversationService.markRead(conversationId);
    _channel = _messageService.subscribeToMessages(
      conversationId: conversationId,
      currentUserId: userId,
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
    await _sendOptimistic(
      optimistic: ChatMessage(
        id: _uuid.v4(),
        body: body.trim(),
        timeLabel: formatMessageTime(DateTime.now()),
        isMine: true,
        status: MessageStatus.sent,
        createdAt: DateTime.now(),
        senderId: userId,
      ),
      send: (clientId) => _messageService.sendMessage(
        conversationId: conversationId,
        body: body,
        currentUserId: userId,
        clientMessageId: clientId,
      ),
    );
  }

  Future<void> sendGif(Uint8List bytes) async {
    if (bytes.isEmpty || isSending) return;
    final clientId = _uuid.v4();
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

  Future<void> _sendOptimistic({
    required ChatMessage optimistic,
    required Future<ChatMessage> Function(String clientId) send,
  }) async {
    isSending = true;
    notifyListeners();

    final clientId = optimistic.id;
    messages = [...messages, optimistic];
    notifyListeners();

    try {
      final saved = await send(clientId);
      messages = messages
          .map((m) => m.id == clientId ? _withTimeLabel(saved) : m)
          .toList();
      error = null;
    } catch (e) {
      messages = messages
          .map(
            (m) => m.id == clientId
                ? m.copyWith(status: MessageStatus.failed, isMine: true)
                : m,
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
    disposeRealtimeChannel(_channel);
    super.dispose();
  }
}
