import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_peer.dart';
import '../services/inbox_service.dart';
import '../utils/list_filter.dart';

class InboxController extends ChangeNotifier {
  InboxController({
    required this.userId,
    required this.inboxService,
    this.enableRealtime = true,
  }) {
    unawaited(_bootstrap());
  }

  final String userId;
  final bool enableRealtime;
  final InboxService inboxService;
  RealtimeChannel? _channel;
  int _loadGeneration = 0;
  bool _realtimeAttached = false;

  List<ChatPeer> peers = [];
  bool isLoading = true;
  String? error;
  String _searchQuery = '';

  List<ChatPeer> get filteredPeers => filterByQueryFields(
        peers,
        _searchQuery,
        (peer) => [peer.displayName, peer.preview, peer.address ?? ''],
      );

  void setSearchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }

  ChatPeer? findByProfileId(String profileId) {
    for (final peer in peers) {
      if (peer.profileId == profileId) return peer;
    }
    return null;
  }

  /// Sessione GoTrue terminata (refresh fallito o sign-out interno).
  void onSessionEnded() {
    peers = [];
    isLoading = false;
    error = 'Sessione scaduta per questo account. Accedi di nuovo.';
    notifyListeners();
  }

  Future<void> _bootstrap() async {
    await load();
    if (enableRealtime) _attachRealtime();
  }

  void _attachRealtime() {
    if (_realtimeAttached) return;
    _realtimeAttached = true;
    _channel = inboxService.subscribeToInbox(userId, load);
  }

  Future<void> load() async {
    final generation = ++_loadGeneration;
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final loaded = await inboxService
          .fetchInbox()
          .timeout(const Duration(seconds: 30));
      if (generation != _loadGeneration) return;
      peers = loaded;
      error = null;
    } on TimeoutException {
      if (generation != _loadGeneration) return;
      error = 'Timeout caricamento inbox. Riprova.';
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

  @override
  void dispose() {
    inboxService.disposeChannel(_channel);
    super.dispose();
  }
}
