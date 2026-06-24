import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/conversation.dart';
import '../services/conversation_service.dart';
import '../services/supabase_bootstrap.dart';

class ConversationsController extends ChangeNotifier {
  ConversationsController({
    required this.userId,
    ConversationService? conversationService,
  }) : _conversationService = conversationService ?? ConversationService() {
    load();
    _channel = _conversationService.subscribeToConversationList(userId, load);
  }

  final String userId;
  final ConversationService _conversationService;
  RealtimeChannel? _channel;

  List<Conversation> conversations = [];
  bool isLoading = true;
  String? error;
  String _searchQuery = '';

  List<Conversation> get filteredConversations {
    if (_searchQuery.isEmpty) return conversations;
    final q = _searchQuery.toLowerCase();
    return conversations
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.preview.toLowerCase().contains(q),
        )
        .toList();
  }

  void setSearchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }

  Future<void> load() async {
    try {
      conversations = await _conversationService.fetchConversations(userId);
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<String> openFromContact(String contactId) async {
    final id =
        await _conversationService.openConversationFromContact(contactId);
    await load();
    return id;
  }

  @override
  void dispose() {
    if (_channel != null) {
      supabase.removeChannel(_channel!);
    }
    super.dispose();
  }
}
