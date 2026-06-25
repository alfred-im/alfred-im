import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import '../models/saved_account.dart';
import '../services/auth_service.dart';
import '../utils/auth_identity.dart';

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
  bool sessionReady = false;
  String? error;

  bool get isAuthenticated => _authService.isAuthenticated;
  String? get userId => _authService.currentUser?.id;
  String? get username => profile?.username;

  Future<void> initialize() async {
    savedAccounts = await _authService.savedAccounts();
    await _loadProfile();
    sessionReady = true;
    notifyListeners();
  }

  /// Prima di aggiungere un altro account: salva la sessione corrente.
  Future<void> prepareAddAccount() async {
    await _authService.persistCurrentSession();
    savedAccounts = await _authService.savedAccounts();
    error = null;
    notifyListeners();
  }

  Future<void> signIn(String username, String password) async {
    final validationError = AuthIdentity.validateUsername(username);
    if (validationError != null) {
      error = validationError;
      notifyListeners();
      return;
    }

    error = null;
    isLoading = true;
    notifyListeners();
    try {
      await _authService.signIn(username: username, password: password);
      savedAccounts = await _authService.savedAccounts();
    } catch (e) {
      error = _friendlyAuthError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signUp({
    required String password,
    required String username,
    required String displayName,
  }) async {
    final validationError = AuthIdentity.validateUsername(username);
    if (validationError != null) {
      error = validationError;
      notifyListeners();
      return;
    }

    if (displayName.trim().isEmpty) {
      error = 'Inserisci un nome visualizzato';
      notifyListeners();
      return;
    }

    error = null;
    isLoading = true;
    notifyListeners();
    try {
      await _authService.signUp(
        password: password,
        username: username,
        displayName: displayName.trim(),
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
      if (msg.contains('invalid login credentials')) {
        return 'Username o password non corretti.';
      }
      if (msg.contains('username già in uso')) {
        return 'Username già in uso. Scegline un altro.';
      }
      if (msg.contains('database error saving new user')) {
        return 'Username già in uso o non valido. Scegline un altro.';
      }
      if (msg.contains('user already registered')) {
        return 'Username già registrato. Prova ad accedere.';
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
