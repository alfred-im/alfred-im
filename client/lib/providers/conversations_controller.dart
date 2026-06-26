import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/conversation.dart';
import '../services/conversation_service.dart';
import '../services/supabase_bootstrap.dart';
import '../utils/list_filter.dart';

class ConversationsController extends ChangeNotifier {
  ConversationsController({
    required this.userId,
    ConversationService? conversationService,
    this.enableRealtime = true,
  }) : _conversationService = conversationService ?? ConversationService() {
    unawaited(_bootstrap());
  }

  final String userId;
  final bool enableRealtime;
  final ConversationService _conversationService;
  RealtimeChannel? _channel;
  int _loadGeneration = 0;
  bool _realtimeAttached = false;

  List<Conversation> conversations = [];
  bool isLoading = true;
  String? error;
  String _searchQuery = '';

  List<Conversation> get filteredConversations => filterByQueryFields(
        conversations,
        _searchQuery,
        (conversation) => [conversation.name, conversation.preview],
      );

  void setSearchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }

  Future<void> _bootstrap() async {
    await load();
    if (enableRealtime) _attachRealtime();
  }

  void _attachRealtime() {
    if (_realtimeAttached) return;
    _realtimeAttached = true;
    _channel = _conversationService.subscribeToConversationList(userId, load);
  }

  Future<void> load() async {
    final generation = ++_loadGeneration;
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final loaded = await _conversationService
          .fetchConversations()
          .timeout(const Duration(seconds: 30));
      if (generation != _loadGeneration) return;
      conversations = loaded;
      error = null;
    } on TimeoutException {
      if (generation != _loadGeneration) return;
      error = 'Timeout caricamento conversazioni. Riprova.';
    } catch (e) {
      if (generation != _loadGeneration) return;
      error = e.toString();
    } finally {
      if (generation == _loadGeneration) {
        isLoading = false;
        notifyListeners();
      }
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
    disposeRealtimeChannel(_channel);
    super.dispose();
  }
}
