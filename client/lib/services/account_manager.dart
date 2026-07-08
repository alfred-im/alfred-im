import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/account_view_state.dart';
import '../models/chat_peer.dart';
import '../models/open_account.dart';
import '../models/profile_summary.dart';
import '../utils/auth_redirect_url.dart';
import 'account_session.dart';
import 'account_storage_service.dart';

/// Gestisce account messaggistica aperti e il focus UI.
///
/// Il manifest ([alfred_saved_accounts]) elenca tutti gli account aperti; in RAM
/// c'è **al massimo una** [AccountSession] GoTrue attiva (quella in focus).
/// Al cambio focus la sessione corrente viene rilasciata (storage auth locale
/// conservato) e si ripristina solo il nuovo account da manifest.
class AccountManager {
  AccountManager({AccountStorageService? storage})
      : _storage = storage ?? AccountStorageService();

  final AccountStorageService _storage;
  final Map<String, AccountSession> _sessions = {};
  final Map<String, AccountViewState> _viewsByAccount = {};
  final Set<String> _testOnlyAccountIds = {};
  List<OpenAccount> _manifestAccounts = [];
  String? _focusUserId;

  /// Tutti gli account aperti (manifest); il focus può avere profilo aggiornato
  /// dalla sessione viva.
  List<OpenAccount> get openAccounts => _manifestAccounts
      .map((account) {
        if (account.userId == _focusUserId) {
          final live = _sessions[_focusUserId];
          if (live != null) return live.toOpenAccount();
        }
        return account;
      })
      .toList();

  List<AccountSession> get sessions => _sessions.values.toList();

  AccountSession? get focusedSession =>
      _focusUserId != null ? _sessions[_focusUserId] : null;

  String? get focusUserId => _focusUserId;

  AccountViewState get viewState => _viewFor(_focusUserId);

  bool get hasOpenAccounts =>
      _manifestAccounts.isNotEmpty || _testOnlyAccountIds.isNotEmpty;

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

  void openGroupChat() {
    final userId = _focusUserId;
    if (userId == null) return;
    _setViewFor(userId, _storedViewFor(userId).openGroupChat());
  }

  void backToGroupHome() {
    final userId = _focusUserId;
    if (userId == null) return;
    _setViewFor(userId, _storedViewFor(userId).backToGroupHome());
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
      _manifestAccounts.any((a) => a.userId == userId) ||
      _testOnlyAccountIds.contains(userId);

  @visibleForTesting
  void seedTestAccount(String userId) {
    _testOnlyAccountIds.add(userId);
  }

  @visibleForTesting
  Future<void> syncManifestFromStorageForTest() => _refreshManifestCache();

  @visibleForTesting
  void injectTestSession(AccountSession session) {
    _sessions[session.userId] = session;
    session.wireStorage(_storage);
  }

  /// Imposta focus su sessione iniettata (test) senza dispose/restore GoTrue.
  @visibleForTesting
  void focusTestSession(AccountSession session) {
    _testOnlyAccountIds.add(session.userId);
    _sessions[session.userId] = session;
    _focusUserId = session.userId;
    session.wireStorage(_storage);
  }

  /// F5 / avvio app: manifest in cache + ripristina solo il focus.
  Future<void> initialize() async {
    await _rebuildFromManifest();
  }

  /// Scrive il token nel manifest e attiva la sessione del nuovo focus.
  Future<AccountSession> openWithPassword({
    required String email,
    required String password,
  }) async {
    await _pauseAuthListeners();
    try {
      final account = await AccountSession.signInOpenAccount(
        email: email,
        password: password,
      );
      await _storage.upsertAccount(account);
      final session = await _rebuildFromManifest(
        focusUserId: account.userId,
        requireSession: true,
      );
      return session!;
    } finally {
      await _resumeAuthListeners();
    }
  }

  Future<AccountSession> openWithSignUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
    ProfileKind profileKind = ProfileKind.user,
  }) async {
    await _pauseAuthListeners();
    try {
      final account = await AccountSession.signUpOpenAccount(
        email: email,
        password: password,
        username: username,
        displayName: displayName,
        profileKind: profileKind,
      );
      await _storage.upsertAccount(account);
      final session = await _rebuildFromManifest(
        focusUserId: account.userId,
        requireSession: true,
      );
      return session!;
    } finally {
      await _resumeAuthListeners();
    }
  }

  /// Aggiorna cache manifest, rilascia sessioni RAM e ripristina solo il focus.
  Future<AccountSession?> _rebuildFromManifest({
    String? focusUserId,
    bool requireSession = false,
  }) async {
    await _disposeSessionsInRam(clearAuthStorage: false);
    await _refreshManifestCache();

    final stored = await _storage.loadAccounts();
    for (final account in stored) {
      if (account.refreshToken.isEmpty) {
        await _storage.removeAccount(account.userId);
      }
    }
    await _refreshManifestCache();

    if (_manifestAccounts.isEmpty) {
      _focusUserId = null;
      if (requireSession) {
        throw const AuthException('Sessione account non disponibile.');
      }
      return null;
    }

    final savedFocus = focusUserId ?? await _storage.loadFocusUserId();
    if (savedFocus != null && _hasAccount(savedFocus)) {
      _focusUserId = savedFocus;
    } else {
      _focusUserId = _manifestAccounts.first.userId;
    }
    await _storage.saveFocusUserId(_focusUserId);

    return _activateFocusedSession(requireSession: requireSession);
  }

  Future<void> _refreshManifestCache() async {
    final stored = await _storage.loadAccounts();
    _manifestAccounts =
        stored.where((a) => a.refreshToken.isNotEmpty).toList();
  }

  /// Ripristina GoTrue solo per [_focusUserId]; su auth permanente prova altro account.
  Future<AccountSession?> _activateFocusedSession({
    bool requireSession = false,
  }) async {
    while (_focusUserId != null) {
      if (_testOnlyAccountIds.contains(_focusUserId)) {
        return null;
      }

      final userId = _focusUserId!;
      final accountIndex =
          _manifestAccounts.indexWhere((a) => a.userId == userId);
      if (accountIndex < 0) {
        if (_manifestAccounts.isEmpty) {
          _focusUserId = null;
          break;
        }
        _focusUserId = _manifestAccounts.first.userId;
        await _storage.saveFocusUserId(_focusUserId);
        continue;
      }
      final account = _manifestAccounts[accountIndex];

      try {
        final session = await _restoreWithRetry(account);
        _sessions.clear();
        _sessions[session.userId] = session;
        session.wireStorage(_storage);
        await _syncFocusedProfile(session);
        return session;
      } catch (e) {
        if (_isPermanentAuthFailure(e)) {
          await _storage.removeAccount(userId);
          await AccountSession.clearLocalAuthStorage(userId);
          await _refreshManifestCache();
          if (_manifestAccounts.isEmpty) {
            _focusUserId = null;
            await _storage.saveFocusUserId(null);
            break;
          }
          if (!_manifestAccounts.any((a) => a.userId == _focusUserId)) {
            _focusUserId = _manifestAccounts.first.userId;
            await _storage.saveFocusUserId(_focusUserId);
          }
          continue;
        }
        if (requireSession) rethrow;
        return null;
      }
    }

    if (requireSession) {
      throw const AuthException('Sessione account non disponibile.');
    }
    return null;
  }

  Future<void> _disposeSessionsInRam({required bool clearAuthStorage}) async {
    for (final session in _sessions.values.toList()) {
      await session.disposeResources(clearAuthStorage: clearAuthStorage);
    }
    _sessions.clear();
  }

  Future<void> _pauseAuthListeners() async {
    for (final session in _sessions.values) {
      await session.pauseAuthListener();
    }
  }

  Future<void> _resumeAuthListeners() async {
    for (final session in _sessions.values) {
      session.resumeAuthListener();
    }
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

  Future<void> setFocus(String userId) async {
    if (!_hasAccount(userId)) return;

    if (_focusUserId == userId) {
      await _loadFocusedInboxIfNeeded();
      return;
    }

    final previousFocus = _focusUserId;

    await _disposeSessionsInRam(clearAuthStorage: false);

    _focusUserId = userId;
    await _storage.saveFocusUserId(userId);

    try {
      if (!_testOnlyAccountIds.contains(userId)) {
        await _activateFocusedSession(requireSession: true);
      }
      await _loadFocusedInboxIfNeeded();
    } catch (e) {
      _focusUserId = previousFocus;
      if (previousFocus != null) {
        await _storage.saveFocusUserId(previousFocus);
      } else {
        await _storage.saveFocusUserId(null);
      }
      if (previousFocus != null &&
          !_testOnlyAccountIds.contains(previousFocus)) {
        try {
          await _activateFocusedSession(requireSession: false);
        } catch (_) {
          // Best-effort restore of the previous session.
        }
      }
      rethrow;
    }
  }

  Future<void> _loadFocusedInboxIfNeeded() async {
    final session = _sessions[_focusUserId];
    if (session == null || session.profile.isGroup) return;
    await session.inboxController.load();
  }

  Future<void> removeAccount(String userId) async {
    _testOnlyAccountIds.remove(userId);
    _viewsByAccount.remove(userId);

    final wasFocused = _focusUserId == userId;
    final session = _sessions.remove(userId);

    if (session != null) {
      await session.clearStoredAccount();
    } else {
      await _storage.removeAccount(userId);
      await AccountSession.clearLocalAuthStorage(userId);
    }

    await _refreshManifestCache();

    if (wasFocused) {
      await _disposeSessionsInRam(clearAuthStorage: false);
      if (_manifestAccounts.isNotEmpty) {
        _focusUserId = _manifestAccounts.first.userId;
        await _storage.saveFocusUserId(_focusUserId);
        await _activateFocusedSession();
      } else {
        _focusUserId = null;
        await _storage.saveFocusUserId(null);
      }
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

  Future<void> _syncFocusedProfile(AccountSession session) async {
    try {
      await session.syncProfileSummary();
      await session.updateStoredProfile(session.profile);
      await _refreshManifestCache();
    } catch (_) {
      // Mantieni la sessione ripristinata anche se il sync profilo fallisce.
    }
  }

  Future<void> refreshOpenAccountProfiles() async {
    final session = focusedSession;
    if (session == null) return;
    await _syncFocusedProfile(session);
  }

  Future<bool> isUsernameAvailable(String username) async {
    final client = focusedSession?.client ??
        AccountSession.createBootstrapClient();
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
    await _disposeSessionsInRam(clearAuthStorage: true);
    _viewsByAccount.clear();
    _testOnlyAccountIds.clear();
    _manifestAccounts = [];
    _focusUserId = null;
  }
}
