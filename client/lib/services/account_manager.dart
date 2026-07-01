import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/account_view_state.dart';
import '../models/chat_peer.dart';
import '../models/open_account.dart';
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

  @visibleForTesting
  void injectTestSession(AccountSession session) {
    _sessions[session.userId] = session;
    _wireSession(session);
  }

  Future<void> initialize() async {
    final stored = await _storage.loadAccounts();
    final savedFocus = await _storage.loadFocusUserId();

    for (final account in stored) {
      if (account.refreshToken.isEmpty) {
        await _storage.removeAccount(account.userId);
        continue;
      }
      try {
        final session = await _restoreWithRetry(account);
        _wireSession(session);
        _sessions[session.userId] = session;
        await _syncManifestRefreshToken(session);
      } catch (e) {
        if (_isPermanentAuthFailure(e)) {
          await _storage.removeAccount(account.userId);
        }
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

  Future<AccountSession> _restoreWithRetry(OpenAccount account) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await AccountSession.restore(account);
      } catch (e) {
        lastError = e;
        if (_isPermanentAuthFailure(e)) rethrow;
        if (attempt < 2) {
          await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
        }
      }
    }
    throw lastError ?? const AuthException('Ripristino account non riuscito.');
  }

  Future<void> _syncManifestRefreshToken(AccountSession session) async {
    final token = session.client.auth.currentSession?.refreshToken;
    if (token == null || token.isEmpty) return;
    await session.updateStoredRefresh(token);
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
      final newToken = session.lastKnownRefreshToken;
      final updatedProfile = session.profile;
      await session.disposeResources(clearAuthStorage: false);
      if (newToken != null && newToken.isNotEmpty) {
        await existing.persistOpenAccount(
          refreshToken: newToken,
          profile: updatedProfile,
        );
      }
      if (focus) {
        await setFocus(session.userId);
      }
      return existing;
    }

    _sessions[session.userId] = session;
    _wireSession(session);
    final token = session.lastKnownRefreshToken;
    if (token != null && token.isNotEmpty) {
      await session.persistOpenAccount(
        refreshToken: token,
        profile: session.profile,
      );
    }
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
    if (session != null) {
      await session.clearStoredAccount();
    }

    if (_focusUserId == userId) {
      _focusUserId = _sessions.keys.isEmpty ? null : _sessions.keys.first;
      await _storage.saveFocusUserId(_focusUserId);
    }
  }

  bool _isPermanentAuthFailure(Object e) {
    if (e is AuthException) {
      final msg = e.message.toLowerCase();
      return msg.contains('invalid refresh') ||
          msg.contains('refresh token not found') ||
          msg.contains('session expired') ||
          msg.contains('token has expired');
    }
    return false;
  }

  Future<void> _syncAllProfiles() async {
    for (final session in _sessions.values) {
      try {
        await session.syncProfileSummary();
        await session.updateStoredProfile(session.profile);
      } catch (_) {
        // Mantieni la sessione ripristinata anche se il sync profilo fallisce.
      }
    }
  }

  Future<void> refreshOpenAccountProfiles() => _syncAllProfiles();

  void _wireSession(AccountSession session) {
    session.wireStorage(_storage);
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
