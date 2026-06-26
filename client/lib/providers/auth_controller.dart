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

  Future<void> signIn(String email, String password) async {
    final validationError = AuthIdentity.validateEmail(email);
    if (validationError != null) {
      error = validationError;
      notifyListeners();
      return;
    }

    await _withLoading(() async {
      await _authService.signIn(email: email, password: password);
      savedAccounts = await _authService.savedAccounts();
    });
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    final emailError = AuthIdentity.validateEmail(email);
    if (emailError != null) {
      error = emailError;
      notifyListeners();
      return;
    }

    final usernameError = AuthIdentity.validateUsername(username);
    if (usernameError != null) {
      error = usernameError;
      notifyListeners();
      return;
    }

    if (displayName.trim().isEmpty) {
      error = 'Inserisci un nome visualizzato';
      notifyListeners();
      return;
    }

    await _withLoading(() async {
      await _authService.signUp(
        email: email,
        password: password,
        username: username,
        displayName: displayName.trim(),
      );
      savedAccounts = await _authService.savedAccounts();
    });
  }

  Future<bool> resetPassword(String email) async {
    final validationError = AuthIdentity.validateEmail(email);
    if (validationError != null) {
      error = validationError;
      notifyListeners();
      return false;
    }

    error = null;
    isLoading = true;
    notifyListeners();
    try {
      await _authService.resetPassword(email);
      return true;
    } catch (e) {
      error = _friendlyAuthError(e);
      return false;
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

  Future<void> refreshProfile() => _loadProfile();

  Future<void> _withLoading(Future<void> Function() action) async {
    error = null;
    isLoading = true;
    notifyListeners();
    try {
      await action();
    } catch (e) {
      error = _friendlyAuthError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  String _friendlyAuthError(Object e) {
    if (e is AuthException) {
      final msg = e.message.toLowerCase();
      if (msg.contains('refresh') || msg.contains('session')) {
        return 'Sessione scaduta per questo account. Usa "Aggiungi account" e accedi di nuovo.';
      }
      if (msg.contains('invalid login credentials')) {
        return 'Email o password non corretti.';
      }
      if (msg.contains('username già in uso')) {
        return 'Username già in uso. Scegline un altro.';
      }
      if (msg.contains('database error saving new user')) {
        return 'Username già in uso o non valido. Scegline un altro.';
      }
      if (msg.contains('user already registered')) {
        return 'Email già registrata. Prova ad accedere.';
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
