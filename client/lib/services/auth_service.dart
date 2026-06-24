import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import '../models/saved_account.dart';
import 'account_storage_service.dart';
import 'supabase_bootstrap.dart';

class AuthService {
  AuthService({AccountStorageService? accountStorage})
      : _accountStorage = accountStorage ?? AccountStorageService();

  final AccountStorageService _accountStorage;

  Session? get session => supabase.auth.currentSession;
  User? get currentUser => supabase.auth.currentUser;
  bool get isAuthenticated => session != null;

  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    await _persistSessionAccount(response.session);
    return response;
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    final response = await supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'username': username.toLowerCase(),
        'display_name': displayName,
      },
    );
    if (response.session != null) {
      await _persistSessionAccount(response.session);
    }
    return response;
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  Future<void> switchAccount(SavedAccount account) async {
    await supabase.auth.setSession(account.refreshToken);
  }

  Future<List<SavedAccount>> savedAccounts() => _accountStorage.loadAccounts();

  Future<void> removeSavedAccount(String userId) =>
      _accountStorage.removeAccount(userId);

  Future<UserProfile?> fetchCurrentProfile() async {
    final userId = currentUser?.id;
    if (userId == null) return null;

    final row = await supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (row == null) return null;
    return UserProfile.fromJson(row);
  }

  Future<void> _persistSessionAccount(Session? session) async {
    if (session == null || session.user.email == null) return;

    final profile = await supabase
        .from('profiles')
        .select('display_name')
        .eq('id', session.user.id)
        .maybeSingle();

    final displayName = profile?['display_name'] as String? ??
        session.user.email!.split('@').first;

    await _accountStorage.upsertAccount(
      SavedAccount(
        userId: session.user.id,
        email: session.user.email!,
        refreshToken: session.refreshToken ?? '',
        displayName: displayName,
      ),
    );
  }
}
