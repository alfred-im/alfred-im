import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import '../models/saved_account.dart';
import '../utils/auth_identity.dart';
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

  /// Salva il refresh token aggiornato dell'account attivo (rotazione token).
  Future<void> persistCurrentSession() async {
    await _persistSessionAccount(session);
  }

  Future<AuthResponse> signIn({
    required String username,
    required String password,
  }) async {
    await persistCurrentSession();

    final normalized = AuthIdentity.normalizeUsername(username);
    final response = await supabase.auth.signInWithPassword(
      email: AuthIdentity.internalAuthEmail(normalized),
      password: password,
    );
    await _persistSessionAccount(response.session);
    return response;
  }

  Future<AuthResponse> signUp({
    required String password,
    required String username,
    required String displayName,
  }) async {
    await persistCurrentSession();

    final normalized = AuthIdentity.normalizeUsername(username);
    final response = await supabase.auth.signUp(
      email: AuthIdentity.internalAuthEmail(normalized),
      password: password,
      data: {
        'username': normalized,
        'display_name': displayName,
      },
    );
    if (response.session != null) {
      await _persistSessionAccount(response.session);
    }
    return response;
  }

  /// Esci dall'account attivo (revoca sessione corrente su Supabase).
  Future<void> signOut() async {
    final userId = currentUser?.id;
    await supabase.auth.signOut();
    if (userId != null) {
      await _accountStorage.removeAccount(userId);
    }
  }

  Future<void> switchAccount(SavedAccount account) async {
    if (account.refreshToken.isEmpty) {
      throw const AuthException('Sessione account non disponibile. Accedi di nuovo.');
    }

    final previousRefresh = session?.refreshToken;

    await persistCurrentSession();

    try {
      final response = await supabase.auth.setSession(account.refreshToken);
      await _persistSessionAccount(response.session);
    } catch (error) {
      if (previousRefresh != null && previousRefresh.isNotEmpty) {
        try {
          await supabase.auth.setSession(previousRefresh);
        } catch (_) {
          // Sessione precedente non recuperabile.
        }
      }
      rethrow;
    }
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
    if (session == null) return;

    final refresh = session.refreshToken;
    if (refresh == null || refresh.isEmpty) return;

    final profile = await supabase
        .from('profiles')
        .select('display_name, username')
        .eq('id', session.user.id)
        .maybeSingle();

    final username = profile?['username'] as String? ??
        AuthIdentity.usernameFromAuthEmail(session.user.email) ??
        session.user.userMetadata?['username'] as String?;

    if (username == null || username.isEmpty) return;

    final displayName = profile?['display_name'] as String? ??
        session.user.userMetadata?['display_name'] as String? ??
        username;

    await _accountStorage.upsertAccount(
      SavedAccount(
        userId: session.user.id,
        username: username,
        refreshToken: refresh,
        displayName: displayName,
      ),
    );
  }
}
