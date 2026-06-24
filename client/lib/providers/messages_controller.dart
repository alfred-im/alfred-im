import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/message.dart';
import '../services/conversation_service.dart';
import '../services/message_service.dart';
import '../services/supabase_bootstrap.dart';
import '../utils/date_format.dart';

class MessagesController extends ChangeNotifier {
  MessagesController({
    required this.conversationId,
    required this.userId,
    MessageService? messageService,
    ConversationService? conversationService,
  })  : _messageService = messageService ?? MessageService(),
        _conversationService = conversationService ?? ConversationService() {
    _init();
  }

  final String conversationId;
  final String userId;
  final MessageService _messageService;
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
    return ChatMessage(
      id: message.id,
      body: message.body,
      timeLabel: formatMessageTime(at),
      isMine: message.isMine,
      status: message.status,
      createdAt: at,
      senderId: message.senderId,
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
    isSending = true;
    notifyListeners();

    final clientId = _uuid.v4();
    final optimistic = ChatMessage(
      id: clientId,
      body: body.trim(),
      timeLabel: formatMessageTime(DateTime.now()),
      isMine: true,
      status: MessageStatus.sent,
      createdAt: DateTime.now(),
      senderId: userId,
    );
    messages = [...messages, optimistic];
    notifyListeners();

    try {
      final saved = await _messageService.sendMessage(
        conversationId: conversationId,
        body: body,
        currentUserId: userId,
        clientMessageId: clientId,
      );
      messages = messages
          .map((m) => m.id == clientId ? _withTimeLabel(saved) : m)
          .toList();
      error = null;
    } catch (e) {
      messages = messages
          .map(
            (m) => m.id == clientId
                ? ChatMessage(
                    id: m.id,
                    body: m.body,
                    timeLabel: m.timeLabel,
                    isMine: true,
                    status: MessageStatus.failed,
                    createdAt: m.createdAt,
                    senderId: userId,
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

  @override
  void dispose() {
    if (_channel != null) {
      supabase.removeChannel(_channel!);
    }
    super.dispose();
  }
}
