// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/manifest_bootstrap.dart';
import '../stores/account_view_state_store.dart';
import '../models/account_view_state.dart';
import '../models/open_account.dart';
import '../models/profile_summary.dart';
import '../models/push_sync_scope.dart';
import '../utils/conversation_session_access.dart';
import '../utils/auth_redirect_url.dart';
import '../utils/diagnostic_log.dart';
import '../utils/friendly_auth_error.dart';
import 'account_session.dart';
import 'account_storage_service.dart';

part 'session_authority.dart';

/// Gestisce I/O account messaggistica: manifest, sessioni GoTrue, storage.
///
/// Il manifest ([alfred_saved_accounts]) elenca tutti gli account aperti; in RAM
/// c'è **al massimo una** [AccountSession] GoTrue attiva (quella in focus).
/// **Il focus intent è deciso da [MultiAccountMachine]**; questo servizio esegue
/// dispose/restore quando comandato via effetti.
class AccountManager {
  AccountManager({AccountStorageService? storage})
      : _storage = storage ?? AccountStorageService() {
    viewStateStore = AccountViewStateStore(this);
    sessionAuthority = SessionAuthority(this);
  }

  /// Enforcement unico identità GoTrue — vedi docs/domain/multi-account/session-authority.md.
  late final SessionAuthority sessionAuthority;

  /// Sostituisce [AccountSession.restore] nei test (percorso dispose + ripristino).
  @visibleForTesting
  Future<AccountSession> Function(OpenAccount account)? restoreSessionForTest;

  /// Chiamato quando il sync profilo in background termina (es. avvio app).
  VoidCallback? onFocusedProfileSynced;

  final AccountStorageService _storage;
  late final AccountViewStateStore viewStateStore;
  final Map<String, AccountSession> _sessions = {};
  final Set<String> _testOnlyAccountIds = {};
  List<OpenAccount> _manifestAccounts = [];
  String? _focusUserId;
  Future<void> _focusOperationChain = Future<void>.value();

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

  AccountViewState get viewState => viewStateStore.viewStateFor(_focusUserId);

  /// View state per account (sanitizzato); sola lettura.
  AccountViewState viewStateFor(String accountUserId) =>
      viewStateStore.viewStateFor(accountUserId);

  bool get hasOpenAccounts =>
      _manifestAccounts.isNotEmpty || _testOnlyAccountIds.isNotEmpty;

  /// Mutazione view-state — solo da [AccountViewStateStore] / navigation.
  void applyAccountViewState(
    String accountUserId,
    AccountViewState Function(AccountViewState current) transform,
  ) {
    viewStateStore.apply(accountUserId, transform);
  }

  /// Account presente nel manifest o nel set di test.
  bool hasOpenAccount(String userId) => _hasAccount(userId);

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

  @visibleForTesting
  void clearSessionsInRamForTest() {
    _sessions.clear();
  }

  /// Imposta focus su sessione iniettata (test) senza dispose/restore GoTrue.
  @visibleForTesting
  void focusTestSession(AccountSession session) {
    _testOnlyAccountIds.add(session.userId);
    _sessions[session.userId] = session;
    _focusUserId = session.userId;
    session.wireStorage(_storage);
  }

  /// Lettura manifest per bootstrap macchina (nessuna decisione focus).
  Future<ManifestBootstrap> loadManifestBootstrap() async {
    await _refreshManifestCache();
    final persistedFocus = await _storage.loadFocusUserId();
    return ManifestBootstrap(
      openAccountUserIds: _manifestAccounts.map((a) => a.userId).toList(),
      persistedFocusUserId: persistedFocus,
    );
  }

  /// F5 / avvio app: carica manifest + esegue focus deciso dalla macchina.
  Future<void> initialize({required String? focusUserId}) async {
    await _refreshManifestCache();
    if (focusUserId != null) {
      await sessionAuthority.requestFocusSwitch(
        focusUserId,
        deferProfileSync: true,
      );
    } else {
      _focusUserId = null;
      await _disposeSessionsInRam(clearAuthStorage: false);
    }
  }

  /// Sign-in → upsert manifest; il focus è comandato dalla macchina.
  Future<String> signInAndUpsertManifest({
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
      await _refreshManifestCache();
      return account.userId;
    } finally {
      await _resumeAuthListeners();
    }
  }

  Future<String> signUpAndUpsertManifest({
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
      await _refreshManifestCache();
      return account.userId;
    } finally {
      await _resumeAuthListeners();
    }
  }

  Future<void> _refreshManifestCache() async {
    _manifestAccounts = await _storage.loadAccounts();
  }

  OpenAccount? openAccountFor(String userId) {
    for (final account in _manifestAccounts) {
      if (account.userId == userId) return account;
    }
    return null;
  }

  bool isAccountDisconnected(String userId) =>
      openAccountFor(userId)?.isDisconnected ?? false;

  /// Errore sessione: mantiene profilo nel manifest, marca disconnesso.
  Future<void> _markAccountSessionDisconnected(String userId) async {
    final account = openAccountFor(userId);
    if (account == null || account.isDisconnected) return;

    await _storage.upsertAccount(account.copyWith(refreshToken: ''));
    await AccountSession.clearLocalAuthStorage(userId);

    final stale = _sessions.remove(userId);
    if (stale != null) {
      await stale.disposeResources(clearAuthStorage: false);
    }
    await _refreshManifestCache();
  }

  /// Ripristina GoTrue per [userId] e opzionalmente persiste il focus.
  Future<AccountSession?> _ensureSessionForAccount(
    String userId, {
    bool requireSession = false,
    bool deferProfileSync = false,
    bool persistFocus = false,
    bool disposeOtherSessions = false,
  }) async {
    if (!_hasAccount(userId)) {
      if (requireSession) {
        throw const AuthException('Sessione account non disponibile.');
      }
      return null;
    }

    if (_testOnlyAccountIds.contains(userId)) {
      return _sessions[userId];
    }

    if (persistFocus) {
      _focusUserId = userId;
      await _storage.saveFocusUserId(userId);
    }

    if (disposeOtherSessions) {
      for (final entry in _sessions.entries.toList()) {
        if (entry.key == userId) continue;
        await entry.value.disposeResources(clearAuthStorage: false);
        _sessions.remove(entry.key);
      }
    }

    if (isSessionReadyForAccount(userId) && _sessions.length == 1) {
      return _sessions[userId];
    }

    final stale = _sessions.remove(userId);
    if (stale != null) {
      await stale.disposeResources(clearAuthStorage: false);
    }

    final accountIndex =
        _manifestAccounts.indexWhere((a) => a.userId == userId);
    if (accountIndex < 0) {
      if (requireSession) {
        throw const AuthException('Sessione account non disponibile.');
      }
      return null;
    }
    final account = _manifestAccounts[accountIndex];

    if (account.isDisconnected) {
      return null;
    }

    try {
      final session = await _restoreWithRetry(account);
      _sessions.clear();
      _sessions[session.userId] = session;
      session.wireStorage(_storage);
      if (deferProfileSync) {
        unawaited(_syncFocusedProfile(session));
      } else {
        await _syncFocusedProfile(session);
      }
      return session;
    } catch (e) {
      if (isPermanentAuthFailure(e)) {
        await _markAccountSessionDisconnected(userId);
        return null;
      }
      if (requireSession) rethrow;
      return null;
    }
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
    final restoreForTest = restoreSessionForTest;
    if (restoreForTest != null) {
      return restoreForTest(account);
    }

    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await AccountSession.restore(account);
      } catch (e) {
        lastError = e;
        if (isPermanentAuthFailure(e)) rethrow;
        if (attempt < 2) {
          await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
        }
      }
    }
    throw lastError ?? const AuthException('Ripristino account non riuscito.');
  }

  /// Account UI in focus: ripristina GoTrue senza fidarsi della sessione in RAM.
  ///
  /// Usato all'ingresso in chat — JWT assente, auth disallineato o sessioni spurie.
  Future<void> _consolidateSessionForAccount(String userId) {
    return _enqueueFocusOperation(
      () => _consolidateSessionForAccountImpl(userId),
    );
  }

  /// Sessione utilizzabile per RPC messaggistica sull'account [userId].
  bool isSessionReadyForAccount(String userId) {
    if (_testOnlyAccountIds.contains(userId)) {
      final session = _sessions[userId];
      return session != null && session.userId == userId;
    }
    final session = _sessions[userId];
    if (session == null || session.userId != userId) return false;
    if (clientHasGoTrueSession(session.client)) {
      return isAccountSessionReady(
        client: session.client,
        focusUserId: userId,
      );
    }
    if (restoreSessionForTest != null) return true;
    return false;
  }

  /// Manifest con account ma sessione GoTrue assente in RAM — ripristina il focus.
  Future<void> _reconnectFocusedSession(String focusUserId) {
    return _enqueueFocusOperation(
      () => _reconnectFocusedSessionImpl(focusUserId),
    );
  }

  Future<void> _reconnectFocusedSessionImpl(String focusUserId) async {
    await _refreshManifestCache();
    if (_manifestAccounts.isEmpty) return;
    if (!_hasAccount(focusUserId)) return;
    await _executeFocusImpl(focusUserId);
  }

  /// Esegue focus comandato dalla macchina (persist + dispose + restore).
  Future<void> _executeFocus(
    String userId, {
    bool deferProfileSync = false,
    VoidCallback? onFocusIdentityChanged,
  }) {
    return _enqueueFocusOperation(
      () => _executeFocusImpl(
        userId,
        deferProfileSync: deferProfileSync,
        onFocusIdentityChanged: onFocusIdentityChanged,
      ),
    );
  }

  Future<void> _enqueueFocusOperation(Future<void> Function() operation) async {
    final previous = _focusOperationChain;
    final gate = Completer<void>();
    _focusOperationChain = gate.future;
    await previous;
    try {
      await operation();
    } finally {
      gate.complete();
    }
  }

  Future<void> _consolidateSessionForAccountImpl(String userId) async {
    if (!_hasAccount(userId)) return;

    if (_focusUserId != userId) {
      await _executeFocusImpl(userId);
      return;
    }

    if (_testOnlyAccountIds.contains(userId)) {
      return;
    }

    await _ensureSessionForAccount(
      userId,
      requireSession: true,
      disposeOtherSessions: true,
      persistFocus: true,
    );
  }

  Future<void> _executeFocusImpl(
    String userId, {
    bool deferProfileSync = false,
    VoidCallback? onFocusIdentityChanged,
  }) async {
    if (!_hasAccount(userId)) return;

    if (_focusUserId == userId) {
      if (!isSessionReadyForAccount(userId) &&
          !_testOnlyAccountIds.contains(userId)) {
        DiagnosticHub.instance.emit(
          DiagnosticFlows.auth,
          'focus.restore',
          data: {'accountUserId': userId},
        );
        await _ensureSessionForAccount(
          userId,
          requireSession: true,
          deferProfileSync: deferProfileSync,
        );
      }
      return;
    }

    final previousFocus = _focusUserId;
    DiagnosticHub.instance.emit(
      DiagnosticFlows.auth,
      'focus.start',
      data: {
        'accountUserId': userId,
        'previousFocus': previousFocus,
      },
    );

    final keepTestSessions = _testOnlyAccountIds.isEmpty
        ? <String, AccountSession>{}
        : Map<String, AccountSession>.fromEntries(
            _sessions.entries.where(
              (entry) => _testOnlyAccountIds.contains(entry.key),
            ),
          );

    if (keepTestSessions.isEmpty) {
      await _disposeSessionsInRam(clearAuthStorage: false);
    } else {
      for (final entry in _sessions.entries.toList()) {
        if (keepTestSessions.containsKey(entry.key)) continue;
        await entry.value.disposeResources(clearAuthStorage: false);
        _sessions.remove(entry.key);
      }
    }

    _focusUserId = userId;
    await _storage.saveFocusUserId(userId);
    onFocusIdentityChanged?.call();

    try {
      if (!_testOnlyAccountIds.contains(userId)) {
        await _ensureSessionForAccount(
          userId,
          requireSession: true,
          deferProfileSync: deferProfileSync,
        );
      }
      DiagnosticHub.instance.emit(
        DiagnosticFlows.auth,
        'focus.ok',
        data: {
          'accountUserId': userId,
          'sessionEpoch': _sessions[userId]?.epoch,
        },
      );
    } catch (e) {
      DiagnosticHub.instance.emitFail(
        DiagnosticFlows.auth,
        'focus.fail',
        e.runtimeType.toString(),
        data: {'accountUserId': userId, 'previousFocus': previousFocus},
      );
      _focusUserId = previousFocus;
      if (previousFocus != null) {
        await _storage.saveFocusUserId(previousFocus);
      } else {
        await _storage.saveFocusUserId(null);
      }
      onFocusIdentityChanged?.call();
      if (previousFocus != null &&
          !_testOnlyAccountIds.contains(previousFocus)) {
        try {
          await _ensureSessionForAccount(
            previousFocus,
            requireSession: false,
          );
        } catch (_) {
          // Best-effort restore of the previous session.
        }
      }
      rethrow;
    }
  }

  /// Carica inbox dell'account in focus (non gruppi). Chiamato dal layer navigation.
  Future<void> refreshFocusedInbox() async {
    final session = _sessions[_focusUserId];
    if (session == null || session.profile.isGroup) return;
    await session.inboxController.load();
  }

  /// Refresh inbox senza spinner lista — non blocca navigazione verso chat.
  Future<void> refreshFocusedInboxSilently() async {
    final session = _sessions[_focusUserId];
    if (session == null || session.profile.isGroup) return;
    await session.inboxController.load(showLoadingIndicator: false);
  }

  /// Rimuove account dal manifest; non decide il prossimo focus (macchina).
  Future<CloseAccountResult> removeAccount(String userId) async {
    _testOnlyAccountIds.remove(userId);
    viewStateStore.clearForAccount(userId);

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
      _focusUserId = null;
    }

    final remaining = _manifestAccounts.map((a) => a.userId).toList();
    return CloseAccountResult(
      wasLastAccount: remaining.isEmpty,
      wasFocused: wasFocused,
      remainingUserIds: remaining,
    );
  }

  Future<void> _syncFocusedProfile(AccountSession session) async {
    try {
      await session.syncProfileSummary();
      await session.updateStoredProfile(session.profile);
      await _refreshManifestCache();
      onFocusedProfileSynced?.call();
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
    viewStateStore.clearAll();
    _testOnlyAccountIds.clear();
    _manifestAccounts = [];
    _focusUserId = null;
  }
}
