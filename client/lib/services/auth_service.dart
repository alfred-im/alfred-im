import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import '../models/profile_summary.dart';
import '../models/saved_account.dart';
import '../utils/auth_identity.dart';
import '../utils/auth_redirect_url.dart';
import 'account_storage_service.dart';
import 'profile_service.dart';
import 'supabase_bootstrap.dart';

class AuthService {
  AuthService({
    AccountStorageService? accountStorage,
    ProfileService? profileService,
  })  : _accountStorage = accountStorage ?? AccountStorageService(),
        _profileService = profileService ?? ProfileService();

  final AccountStorageService _accountStorage;
  final ProfileService _profileService;

  Session? get session => supabase.auth.currentSession;
  User? get currentUser => supabase.auth.currentUser;
  bool get isAuthenticated => session != null;

  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  /// Salva il refresh token aggiornato dell'account attivo (rotazione token).
  Future<void> persistCurrentSession() async {
    await _persistSessionAccount(session);
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    await persistCurrentSession();

    final normalizedEmail = AuthIdentity.normalizeEmail(email);
    final response = await supabase.auth.signInWithPassword(
      email: normalizedEmail,
      password: password,
    );
    await _persistSessionAccount(response.session);
    return response;
  }

  Future<bool> isUsernameAvailable(String username) async {
    final normalized = AuthIdentity.normalizeUsername(username);
    if (!AuthIdentity.isValidUsername(normalized)) return false;

    final available = await supabase.rpc(
      'is_username_available',
      params: {'p_username': normalized},
    );
    return available == true;
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    await persistCurrentSession();

    final normalizedEmail = AuthIdentity.normalizeEmail(email);
    final normalized = AuthIdentity.normalizeUsername(username);
    final available = await isUsernameAvailable(normalized);
    if (!available) {
      throw const AuthException('Username già in uso. Scegline un altro.');
    }

    final response = await supabase.auth.signUp(
      email: normalizedEmail,
      password: password,
      emailRedirectTo: AuthRedirectUrl.resolve(),
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

  Future<void> resetPassword(String email) async {
    final normalizedEmail = AuthIdentity.normalizeEmail(email);
    await supabase.auth.resetPasswordForEmail(
      normalizedEmail,
      redirectTo: AuthRedirectUrl.resolve(),
    );
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

  /// Aggiorna metadati profilo degli account salvati via [ProfileService].
  Future<List<SavedAccount>> syncSavedAccountsFromProfiles() async {
    final accounts = await _accountStorage.loadAccounts();
    if (accounts.isEmpty) return accounts;

    final summaries = await _profileService.fetchSummariesByIds(
      accounts.map((a) => a.userId).toList(),
    );
    final byId = {for (final summary in summaries) summary.id: summary};

    final synced = <SavedAccount>[];
    for (final account in accounts) {
      final summary = byId[account.userId];
      if (summary == null) {
        synced.add(account);
        continue;
      }

      final updated = SavedAccount(
        profile: summary,
        refreshToken: account.refreshToken,
      );
      await _accountStorage.upsertAccount(updated);
      synced.add(updated);
    }

    return synced;
  }

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

    final row = await supabase
        .from('profiles')
        .select('id, display_name, username, avatar_url, pronouns')
        .eq('id', session.user.id)
        .maybeSingle();

    final username = row?['username'] as String? ??
        session.user.userMetadata?['username'] as String?;

    if (username == null || username.isEmpty) return;

    final summary = row != null
        ? ProfileSummary.fromProfilesRow(row)
        : ProfileSummary(
            id: session.user.id,
            username: username,
            displayName: session.user.userMetadata?['display_name'] as String? ??
                username,
          );

    await _accountStorage.upsertAccount(
      SavedAccount(profile: summary, refreshToken: refresh),
    );
  }
}
