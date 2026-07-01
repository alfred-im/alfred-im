import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/open_account.dart';
import '../models/profile.dart';
import '../models/profile_summary.dart';
import '../providers/inbox_controller.dart';
import '../utils/auth_identity.dart';
import '../utils/auth_redirect_url.dart';
import '../utils/ephemeral_pkce_storage.dart';
import 'compose_service.dart';
import 'contact_service.dart';
import 'inbox_service.dart';
import 'message_media_service.dart';
import 'message_service.dart';
import 'profile_avatar_service.dart';
import 'profile_service.dart';

/// Sessione Supabase dedicata a un account messaggistica aperto.
class AccountSession {
  AccountSession._({
    required this.userId,
    required this.client,
    required this.inboxService,
    required this.messageService,
    required this.profileService,
    required this.contactService,
    required this.profileAvatarService,
    required this.messageMediaService,
    required this.composeService,
    required this.inboxController,
    required this.profile,
  });

  final String userId;
  final SupabaseClient client;
  final InboxService inboxService;
  final MessageService messageService;
  final ProfileService profileService;
  final ContactService contactService;
  final ProfileAvatarService profileAvatarService;
  final MessageMediaService messageMediaService;
  final ComposeService composeService;
  final InboxController inboxController;

  ProfileSummary profile;
  UserProfile? fullProfile;
  StreamSubscription<AuthState>? _authSubscription;
  Future<void> Function()? onPersistRequested;

  /// Solo test: refresh token senza setSession (evita rete GoTrue).
  @visibleForTesting
  String? testRefreshTokenOverride;

  String? get refreshToken =>
      testRefreshTokenOverride ?? client.auth.currentSession?.refreshToken;

  /// Refresh token per persistenza: RAM → storage GoTrue → fallback esplicito.
  Future<String?> resolvePersistableRefreshToken({
    String? fallbackRefresh,
  }) async {
    final inMemory = refreshToken;
    if (inMemory != null && inMemory.isNotEmpty) return inMemory;

    final fromGoTrue = await _refreshTokenFromGoTrueStorage();
    if (fromGoTrue != null && fromGoTrue.isNotEmpty) return fromGoTrue;

    if (fallbackRefresh != null && fallbackRefresh.isNotEmpty) {
      return fallbackRefresh;
    }
    return null;
  }

  Future<String?> _refreshTokenFromGoTrueStorage() async {
    final storage = SharedPreferencesLocalStorage(
      persistSessionKey: authStorageKey(userId),
    );
    await storage.initialize();
    final raw = await storage.accessToken();
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final token = decoded['refresh_token'] as String?;
        if (token != null && token.isNotEmpty) return token;
      }
    } catch (_) {
      // Sessione GoTrue malformata in storage — ignora.
    }
    return null;
  }

  /// Chiave storage GoTrue per questo account (`SharedPreferencesLocalStorage`).
  static String authStorageKey(String userId) => 'alfred_auth_$userId';

  OpenAccount toOpenAccount() => OpenAccount(
        profile: profile,
        refreshToken: refreshToken ?? '',
      );

  static SupabaseClient createClient(String storageScope) {
    return SupabaseClient(
      AppConfig.supabaseUrl,
      AppConfig.supabaseAnonKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: SharedPreferencesLocalStorage(
          persistSessionKey: authStorageKey(storageScope),
        ),
        detectSessionInUri: false,
      ),
    );
  }

  /// Client effimero per login/registrazione — niente persistenza sessione né auto-refresh.
  ///
  /// PKCE (default) richiede [pkceAsyncStorage]: senza, `resetPasswordForEmail`
  /// crasha lato client. [EphemeralPkceStorage] tiene il code verifier in RAM.
  ///
  /// Non chiamare mai [GoTrueClient.signOut] sul bootstrap dopo
  /// [_sessionFromAuthResponse]: bootstrap e client dedicato condividono la
  /// stessa sessione GoTrue; il logout server-side revoca il refresh token appena
  /// adottato («Invalid Refresh Token: Refresh Token Not Found»).
  static SupabaseClient createBootstrapClient() {
    return SupabaseClient(
      AppConfig.supabaseUrl,
      AppConfig.supabaseAnonKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: const EmptyLocalStorage(),
        detectSessionInUri: false,
        autoRefreshToken: false,
        pkceAsyncStorage: EphemeralPkceStorage(),
      ),
    );
  }

  static Future<AccountSession> _sessionFromAuthResponse(
    AuthResponse response, {
    ProfileSummary? profileOverride,
  }) async {
    final session = response.session;
    if (session == null) {
      throw const AuthException('Accesso non riuscito.');
    }
    final refresh = session.refreshToken;
    if (refresh == null || refresh.isEmpty) {
      throw const AuthException('Sessione non disponibile.');
    }

    final client = createClient(session.user.id);
    await client.auth.setSession(
      refresh,
      accessToken: session.accessToken,
    );

    return _fromClient(
      client: client,
      initialProfile: profileOverride ?? _profileFromUser(session.user),
    );
  }

  static Future<AccountSession> restore(OpenAccount stored) async {
    final client = createClient(stored.userId);
    await client.auth.setSession(stored.refreshToken);
    return _fromClient(
      client: client,
      initialProfile: stored.profile,
    );
  }

  static Future<AccountSession> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final bootstrap = createBootstrapClient();
    final normalizedEmail = AuthIdentity.normalizeEmail(email);
    final response = await bootstrap.auth.signInWithPassword(
      email: normalizedEmail,
      password: password,
    );
    return _sessionFromAuthResponse(response);
  }

  static Future<AccountSession> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    final bootstrap = createBootstrapClient();
    final normalizedEmail = AuthIdentity.normalizeEmail(email);
    final normalized = AuthIdentity.normalizeUsername(username);
    final available = await bootstrap.rpc(
      'is_username_available',
      params: {'p_username': normalized},
    );
    if (available != true) {
      throw const AuthException('Username già in uso. Scegline un altro.');
    }

    final response = await bootstrap.auth.signUp(
      email: normalizedEmail,
      password: password,
      emailRedirectTo: AuthRedirectUrl.resolve(),
      data: {
        'username': normalized,
        'display_name': displayName,
      },
    );
    final session = response.session;
    if (session == null) {
      throw const AuthException(
        'Registrazione inviata. Conferma l\'email prima di accedere.',
      );
    }
    return _sessionFromAuthResponse(
      response,
      profileOverride: ProfileSummary(
        id: session.user.id,
        username: normalized,
        displayName: displayName,
      ),
    );
  }

  static Future<AccountSession> _fromClient({
    required SupabaseClient client,
    required ProfileSummary initialProfile,
    bool skipHydrate = false,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('Sessione account non disponibile.');
    }

    final inboxService = InboxService(client);
    final profileService = ProfileService(client);
    final session = AccountSession._(
      userId: userId,
      client: client,
      inboxService: inboxService,
      messageService: MessageService(client),
      profileService: profileService,
      contactService: ContactService(client),
      profileAvatarService: ProfileAvatarService(client),
      messageMediaService: MessageMediaService(client),
      composeService: ComposeService(profileService: profileService),
      inboxController: InboxController(
        userId: userId,
        inboxService: inboxService,
      ),
      profile: initialProfile,
    );

    await session._hydrateProfile(skipNetwork: skipHydrate);
    session._listenAuth();
    return session;
  }

  void _listenAuth() {
    _authSubscription = client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.tokenRefreshed) {
        unawaited(onPersistRequested?.call());
      }
    });
  }

  Future<void> _hydrateProfile({bool skipNetwork = false}) async {
    if (skipNetwork) return;
    fullProfile = await fetchFullProfile();
    if (fullProfile != null) {
      profile = fullProfile!.summary;
      return;
    }

    final row = await client
        .from('profiles')
        .select('id, display_name, username, avatar_url, pronouns')
        .eq('id', userId)
        .maybeSingle();

    if (row != null) {
      profile = ProfileSummary.fromProfilesRow(row);
      return;
    }

    final user = client.auth.currentUser;
    final username = user?.userMetadata?['username'] as String?;
    if (username != null && username.isNotEmpty) {
      profile = ProfileSummary(
        id: userId,
        username: username,
        displayName: user?.userMetadata?['display_name'] as String? ?? username,
      );
    }
  }

  Future<UserProfile?> fetchFullProfile() async {
    final row = await client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return UserProfile.fromJson(row);
  }

  Future<void> syncProfileSummary() async {
    await _hydrateProfile();
  }

  /// Rilascia risorse in RAM; opzionalmente cancella storage GoTrue locale.
  Future<void> disposeResources({bool clearAuthStorage = true}) async {
    await _authSubscription?.cancel();
    _authSubscription = null;
    inboxController.dispose();
    if (clearAuthStorage) {
      await _clearLocalAuthOnly();
    }
  }

  /// Chiude la sessione **solo su questo dispositivo** — nessuna revoca GoTrue.
  ///
  /// Non usare [GoTrueClient.signOut]: anche con `scope=local` il server invalida
  /// il refresh token di questa sessione; Alfred deve solo smettere di usare
  /// l'account in locale (altri dispositivi restano connessi).
  Future<void> close() => disposeResources(clearAuthStorage: true);

  Future<void> _clearLocalAuthOnly() async {
    final storage = SharedPreferencesLocalStorage(
      persistSessionKey: authStorageKey(userId),
    );
    await storage.initialize();
    await storage.removePersistedSession();
  }

  /// Sessione in-memory per test (nessuna rete).
  @visibleForTesting
  static Future<AccountSession> createForTest({
    required ProfileSummary profile,
    String refreshToken = 'test-refresh-token',
  }) async {
    final client = createClient(profile.id);
    final inboxService = InboxService(client);
    final profileService = ProfileService(client);
    final session = AccountSession._(
      userId: profile.id,
      client: client,
      inboxService: inboxService,
      messageService: MessageService(client),
      profileService: profileService,
      contactService: ContactService(client),
      profileAvatarService: ProfileAvatarService(client),
      messageMediaService: MessageMediaService(client),
      composeService: ComposeService(profileService: profileService),
      inboxController: InboxController(
        userId: profile.id,
        inboxService: inboxService,
        enableRealtime: false,
      ),
      profile: profile,
    )..testRefreshTokenOverride = refreshToken;
    return session;
  }

  static ProfileSummary _profileFromUser(User user) {
    final username = user.userMetadata?['username'] as String? ?? '';
    final displayName =
        user.userMetadata?['display_name'] as String? ?? username;
    return ProfileSummary(
      id: user.id,
      username: username.isEmpty ? null : username,
      displayName: displayName.isEmpty ? user.email ?? user.id : displayName,
    );
  }
}
