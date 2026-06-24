import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import '../models/saved_account.dart';
import '../services/auth_service.dart';

class AuthController extends ChangeNotifier {
  AuthController({AuthService? authService})
      : _authService = authService ?? AuthService() {
    _subscription = _authService.authStateChanges.listen((_) {
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

  Future<void> signIn(String email, String password) async {
    error = null;
    isLoading = true;
    notifyListeners();
    try {
      await _authService.signIn(email: email, password: password);
      savedAccounts = await _authService.savedAccounts();
    } catch (e) {
      error = e.toString();
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
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    profile = null;
    notifyListeners();
  }

  Future<void> switchAccount(SavedAccount account) async {
    isLoading = true;
    notifyListeners();
    try {
      await _authService.switchAccount(account);
      savedAccounts = await _authService.savedAccounts();
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
