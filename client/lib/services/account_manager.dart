import 'package:flutter/foundation.dart';

import '../models/open_account.dart';
import '../models/account_view_state.dart';
import '../models/chat_peer.dart';
import '../utils/auth_redirect_url.dart';
import 'account_session.dart';
import 'account_storage_service.dart';

/// Gestisce account messaggistica aperti in parallelo e il focus UI.
class AccountManager {
  AccountManager({AccountStorageService? storage})
      : _storage = storage ?? AccountStorageService();

  final AccountStorageService _storage;
  final Map<String, AccountSession> _sessions = {};
  final Map<String, AccountViewState> _viewsByAccount = {};
  final Set<String> _testOnlyAccountIds = {};
  String? _focusUserId;

  List<OpenAccount> get openAccounts =>
      _sessions.values.map((s) => s.toOpenAccount()).toList();

  List<AccountSession> get sessions => _sessions.values.toList();

  AccountSession? get focusedSession =>
      _focusUserId != null ? _sessions[_focusUserId] : null;

  String? get focusUserId => _focusUserId;

  AccountViewState get viewState => _viewFor(_focusUserId);

  bool get hasOpenAccounts => _sessions.isNotEmpty;

  void openConversation(ChatPeer peer) {
    final userId = _focusUserId;
    if (userId == null || peer.profileId == userId) return;
    _setViewFor(userId, _storedViewFor(userId).openChat(peer));
  }

  void showInboxOnMobile() {
    final userId = _focusUserId;
    if (userId == null) return;
    _setViewFor(userId, _storedViewFor(userId).backToInboxOnMobile());
  }

  void mergeActivePeerFromInbox(ChatPeer inboxRow) {
    final userId = _focusUserId;
    if (userId == null) return;
    _setViewFor(userId, _storedViewFor(userId).mergeActivePeer(inboxRow));
  }

  AccountViewState _viewFor(String? userId) {
    if (userId == null) return const AccountViewState();
    return _sanitizeView(userId, _storedViewFor(userId));
  }

  AccountViewState _storedViewFor(String userId) =>
      _viewsByAccount[userId] ?? const AccountViewState();

  AccountViewState _sanitizeView(String userId, AccountViewState view) =>
      view.sanitizedForAccount(userId);

  void _setViewFor(String userId, AccountViewState view) {
    _viewsByAccount[userId] = _sanitizeView(userId, view);
  }

  bool _hasAccount(String userId) =>
      _sessions.containsKey(userId) || _testOnlyAccountIds.contains(userId);

  @visibleForTesting
  void seedTestAccount(String userId) {
    _testOnlyAccountIds.add(userId);
  }

  Future<void> initialize() async {
    final stored = await _storage.loadAccounts();
    final savedFocus = await _storage.loadFocusUserId();

    for (final account in stored) {
      if (account.refreshToken.isEmpty) continue;
      try {
        final session = await AccountSession.restore(account);
        _wireSession(session);
        _sessions[session.userId] = session;
      } catch (_) {
        await _storage.removeAccount(account.userId);
      }
    }

    if (_sessions.isNotEmpty) {
      if (savedFocus != null && _sessions.containsKey(savedFocus)) {
        _focusUserId = savedFocus;
      } else {
        _focusUserId = _sessions.keys.first;
        await _storage.saveFocusUserId(_focusUserId);
      }
    }

    await _syncAllProfiles();
  }

  Future<AccountSession> openWithPassword({
    required String email,
    required String password,
  }) async {
    final session = await AccountSession.signInWithPassword(
      email: email,
      password: password,
    );
    return _adoptSession(session, focus: true);
  }

  Future<AccountSession> openWithSignUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    final session = await AccountSession.signUp(
      email: email,
      password: password,
      username: username,
      displayName: displayName,
    );
    return _adoptSession(session, focus: true);
  }

  Future<AccountSession> _adoptSession(
    AccountSession session, {
    required bool focus,
  }) async {
    final existing = _sessions[session.userId];
    if (existing != null) {
      await session.close();
      if (focus) {
        await setFocus(session.userId);
      }
      return existing;
    }

    _sessions[session.userId] = session;
    _wireSession(session);
    await _persistSession(session);
    if (focus) {
      await setFocus(session.userId);
    }
    return session;
  }

  Future<void> setFocus(String userId) async {
    if (!_hasAccount(userId)) return;
    _focusUserId = userId;
    await _storage.saveFocusUserId(userId);
  }

  Future<void> removeAccount(String userId) async {
    final session = _sessions.remove(userId);
    _testOnlyAccountIds.remove(userId);
    _viewsByAccount.remove(userId);
    await session?.close();
    await _storage.removeAccount(userId);

    if (_focusUserId == userId) {
      _focusUserId = _sessions.keys.isEmpty ? null : _sessions.keys.first;
      await _storage.saveFocusUserId(_focusUserId);
    }
  }

  Future<void> persistSession(AccountSession session) => _persistSession(session);

  Future<void> _persistSession(AccountSession session) async {
    final refresh = session.refreshToken;
    if (refresh == null || refresh.isEmpty) return;
    if (session.profile.username == null || session.profile.username!.isEmpty) {
      return;
    }
    await _storage.upsertAccount(
      OpenAccount(profile: session.profile, refreshToken: refresh),
    );
  }

  Future<void> _syncAllProfiles() async {
    for (final session in _sessions.values) {
      await session.syncProfileSummary();
      await _persistSession(session);
    }
  }

  Future<void> refreshOpenAccountProfiles() => _syncAllProfiles();

  void _wireSession(AccountSession session) {
    session.onPersistRequested = () => _persistSession(session);
  }

  Future<bool> isUsernameAvailable(String username) async {
    final client = _sessions.values.isEmpty
        ? AccountSession.createBootstrapClient()
        : _sessions.values.first.client;
    final normalized = username.trim().toLowerCase();
    final available = await client.rpc(
      'is_username_available',
      params: {'p_username': normalized},
    );
    return available == true;
  }

  Future<void> resetPassword(String email) async {
    final client = AccountSession.createBootstrapClient();
    final normalizedEmail = email.trim().toLowerCase();
    await client.auth.resetPasswordForEmail(
      normalizedEmail,
      redirectTo: AuthRedirectUrl.resolve(),
    );
  }

  Future<void> dispose() async {
    for (final session in _sessions.values.toList()) {
      await session.close();
    }
    _sessions.clear();
    _viewsByAccount.clear();
    _testOnlyAccountIds.clear();
    _focusUserId = null;
  }
}
