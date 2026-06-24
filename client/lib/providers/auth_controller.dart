import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import '../models/saved_account.dart';
import '../services/auth_service.dart';

class AuthController extends ChangeNotifier {
  AuthController({AuthService? authService})
      : _authService = authService ?? AuthService() {
    _subscription = _authService.authStateChanges.listen((state) {
      if (state.event == AuthChangeEvent.tokenRefreshed) {
        unawaited(_authService.persistCurrentSession());
      }
      _loadProfile();
    });
    _loadProfile();
  }

  final AuthService _authService;
  late final StreamSubscription<AuthState> _subscription;

  UserProfile? profile;
  List<SavedAccount> savedAccounts = [];
  bool isLoading = true;
  String? error;

  bool get isAuthenticated => _authService.isAuthenticated;
  String? get userId => _authService.currentUser?.id;
  String? get email => _authService.currentUser?.email;

  Future<void> initialize() async {
    savedAccounts = await _authService.savedAccounts();
    await _loadProfile();
  }

  /// Prima di aggiungere un altro account: salva la sessione corrente.
  Future<void> prepareAddAccount() async {
    await _authService.persistCurrentSession();
    savedAccounts = await _authService.savedAccounts();
    error = null;
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    error = null;
    isLoading = true;
    notifyListeners();
    try {
      await _authService.signIn(email: email, password: password);
      savedAccounts = await _authService.savedAccounts();
    } catch (e) {
      error = _friendlyAuthError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    error = null;
    isLoading = true;
    notifyListeners();
    try {
      await _authService.signUp(
        email: email,
        password: password,
        username: username,
        displayName: displayName,
      );
      savedAccounts = await _authService.savedAccounts();
    } catch (e) {
      error = _friendlyAuthError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    profile = null;
    savedAccounts = await _authService.savedAccounts();
    notifyListeners();
  }

  Future<bool> switchAccount(SavedAccount account) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _authService.switchAccount(account);
      savedAccounts = await _authService.savedAccounts();
      await _loadProfile();
      return true;
    } catch (e) {
      error = _friendlyAuthError(e);
      await _loadProfile();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> removeSavedAccount(String userId) async {
    await _authService.removeSavedAccount(userId);
    savedAccounts = await _authService.savedAccounts();
    notifyListeners();
  }

  Future<void> refreshProfile() => _loadProfile();

  String _friendlyAuthError(Object e) {
    if (e is AuthException) {
      final msg = e.message.toLowerCase();
      if (msg.contains('refresh') || msg.contains('session')) {
        return 'Sessione scaduta per questo account. Usa "Aggiungi account" e accedi di nuovo.';
      }
      return e.message;
    }
    return e.toString();
  }

  Future<void> _loadProfile() async {
    if (!_authService.isAuthenticated) {
      profile = null;
      isLoading = false;
      notifyListeners();
      return;
    }
    profile = await _authService.fetchCurrentProfile();
    isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
