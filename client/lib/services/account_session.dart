import 'dart:async';

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
import 'account_storage_service.dart';
import 'compose_service.dart';
import 'contact_service.dart';
import 'inbox_service.dart';
import 'message_media_service.dart';
import 'message_service.dart';
import 'profile_avatar_service.dart';
import 'profile_service.dart';
import 'reception_allowlist_service.dart';

/// Sessione Supabase dedicata a un account messaggistica aperto.
class AccountSession {
  AccountSession._({
    required this.userId,
    required this.client,
    required this.inboxService,
    required this.messageService,
    required this.profileService,
    required this.contactService,
    required this.receptionAllowlistService,
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
  final ReceptionAllowlistService receptionAllowlistService;
  final ProfileAvatarService profileAvatarService;
  final MessageMediaService messageMediaService;
  final ComposeService composeService;
  final InboxController inboxController;

  ProfileSummary profile;
  UserProfile? fullProfile;
  StreamSubscription<AuthState>? _authSubscription;
  AccountStorageService? _storage;
  String? _lastKnownRefreshToken;

  /// Solo test: **non** usare come unica prova di persistenza su disco.
  @visibleForTesting
  String? testRefreshTokenOverride;

  String? get lastKnownRefreshToken =>
      _lastKnownRefreshToken ?? testRefreshTokenOverride;

  /// Chiave storage GoTrue per questo account (`SharedPreferencesLocalStorage`).
  static String authStorageKey(String userId) => 'alfred_auth_$userId';

  OpenAccount toOpenAccount() => OpenAccount(
        profile: profile,
        refreshToken: lastKnownRefreshToken ?? '',
      );

  void wireStorage(AccountStorageService storage) {
    _storage = storage;
    _ensureAuthListener();
  }

  AccountStorageService _requireStorage() {
    final storage = _storage;
    if (storage == null) {
      throw StateError('AccountStorageService non collegato alla sessione.');
    }
    return storage;
  }

  Future<void> persistOpenAccount({
    required String refreshToken,
    ProfileSummary? profile,
  }) async {
    _lastKnownRefreshToken = refreshToken;
    final profileToStore = profile ?? this.profile;
    await _requireStorage().upsertAccount(
      OpenAccount(profile: profileToStore, refreshToken: refreshToken),
    );
  }

  Future<void> updateStoredProfile(ProfileSummary profile) async {
    this.profile = profile;
    // Non riscrivere il token da RAM: leggi quello già salvato per questo userId.
    final accounts = await _requireStorage().loadAccounts();
    final existing = accounts.where((a) => a.userId == userId).firstOrNull;
    final token = existing?.refreshToken ?? _lastKnownRefreshToken;
    if (token == null || token.isEmpty) return;
    await persistOpenAccount(refreshToken: token, profile: profile);
  }

  Future<void> clearStoredAccount() async {
    final storage = _storage;
    if (storage != null) {
      await storage.removeAccount(userId);
    }
    await disposeResources(clearAuthStorage: true);
  }

  bool hasValidJwt() {
    final access = client.auth.currentSession?.accessToken;
    return access != null && access.isNotEmpty;
  }

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
  /// [openAccountFromAuthResponse]: bootstrap e client dedicato condividono la
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

  /// Login/sign-up: scrive la sessione GoTrue locale e restituisce la voce manifest.
  /// Nessun oggetto runtime — [AccountManager] ricostruisce la RAM con [restore].
  static Future<OpenAccount> openAccountFromAuthResponse(
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

    return OpenAccount(
      profile: profileOverride ?? _profileFromUser(session.user),
      refreshToken: refresh,
    );
  }

  /// Ripristina sessione da manifest + storage GoTrue locale.
  ///
  /// Su F5 web prova prima [recoverSession] da `alfred_auth_{userId}` (senza
  /// rete se la sessione locale è ancora valida), poi fallback su refresh token
  /// del manifest.
  static Future<AccountSession> restore(
    OpenAccount stored, {
    bool skipHydrate = true,
  }) async {
    final client = createClient(stored.userId);
    var refreshToken = stored.refreshToken;

    final recoveredLocally = await _tryRecoverFromLocalAuth(client, stored.userId);
    if (!recoveredLocally) {
      final response = await client.auth.setSession(stored.refreshToken);
      refreshToken =
          response.session?.refreshToken ?? stored.refreshToken;
    } else {
      refreshToken =
          client.auth.currentSession?.refreshToken ?? stored.refreshToken;
    }

    if (client.auth.currentUser == null) {
      throw const AuthException('Sessione account non disponibile.');
    }

    final accountSession = await _fromClient(
      client: client,
      initialProfile: stored.profile,
      skipHydrate: skipHydrate,
    );
    accountSession._lastKnownRefreshToken = refreshToken;
    return accountSession;
  }

  static Future<bool> _tryRecoverFromLocalAuth(
    SupabaseClient client,
    String userId,
  ) async {
    final storage = SharedPreferencesLocalStorage(
      persistSessionKey: authStorageKey(userId),
    );
    await storage.initialize();
    if (!await storage.hasAccessToken()) return false;

    final persisted = await storage.accessToken();
    if (persisted == null || persisted.isEmpty) return false;

    try {
      await client.auth.recoverSession(persisted);
      return client.auth.currentSession != null;
    } catch (_) {
      return false;
    }
  }

  static Future<OpenAccount> signInOpenAccount({
    required String email,
    required String password,
  }) async {
    final bootstrap = createBootstrapClient();
    final normalizedEmail = AuthIdentity.normalizeEmail(email);
    final response = await bootstrap.auth.signInWithPassword(
      email: normalizedEmail,
      password: password,
    );
    return openAccountFromAuthResponse(response);
  }

  static Future<OpenAccount> signUpOpenAccount({
    required String email,
    required String password,
    required String username,
    required String displayName,
    ProfileKind profileKind = ProfileKind.user,
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
        'profile_kind': profileKind.wireValue,
      },
    );
    final session = response.session;
    if (session == null) {
      throw const AuthException(
        'Registrazione inviata. Conferma l\'email prima di accedere.',
      );
    }
    return openAccountFromAuthResponse(
      response,
      profileOverride: ProfileSummary(
        id: session.user.id,
        username: normalized,
        displayName: displayName,
        profileKind: profileKind,
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
      receptionAllowlistService: ReceptionAllowlistService(client),
      profileAvatarService: ProfileAvatarService(client),
      messageMediaService: MessageMediaService(client),
      composeService: ComposeService(profileService: profileService),
      inboxController: InboxController(
        userId: userId,
        inboxService: inboxService,
        enableInboxLoads: !initialProfile.isGroup,
      ),
      profile: initialProfile,
    );

    await session._hydrateProfile(skipNetwork: skipHydrate);
    return session;
  }

  void _ensureAuthListener() {
    if (_authSubscription != null) return;
    _listenAuth();
  }

  /// Silenzia il listener durante login add-account (evita token cross-account).
  Future<void> pauseAuthListener() async {
    await _authSubscription?.cancel();
    _authSubscription = null;
  }

  void resumeAuthListener() => _ensureAuthListener();

  void _listenAuth() {
    _authSubscription = client.auth.onAuthStateChange.listen((state) {
      if (state.event != AuthChangeEvent.tokenRefreshed) return;
      final session = state.session;
      // Ogni SupabaseClient ha il proprio storage, ma su web gli eventi auth
      // possono propagarsi: persistere solo se la sessione è di QUESTO account.
      if (session?.user.id != userId) return;
      final token = session?.refreshToken;
      if (token != null && token.isNotEmpty) {
        unawaited(persistOpenAccount(refreshToken: token));
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
        .select('id, display_name, username, avatar_url, pronouns, profile_kind')
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
        profileKind: ProfileKind.fromString(
          user?.userMetadata?['profile_kind'] as String?,
        ),
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

  Future<void> _clearLocalAuthOnly() async =>
      clearLocalAuthStorage(userId);

  /// Rimuove `alfred_auth_{userId}` senza toccare il manifest.
  static Future<void> clearLocalAuthStorage(String userId) async {
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
    SupabaseClient? client,
    MessageService? messageService,
    MessageMediaService? messageMediaService,
  }) async {
    final resolvedClient = client ?? createClient(profile.id);
    final inboxService = InboxService(resolvedClient);
    final profileService = ProfileService(resolvedClient);
    final session = AccountSession._(
      userId: profile.id,
      client: resolvedClient,
      inboxService: inboxService,
      messageService: messageService ?? MessageService(resolvedClient),
      profileService: profileService,
      contactService: ContactService(resolvedClient),
      receptionAllowlistService: ReceptionAllowlistService(resolvedClient),
      profileAvatarService: ProfileAvatarService(resolvedClient),
      messageMediaService:
          messageMediaService ?? MessageMediaService(resolvedClient),
      composeService: ComposeService(profileService: profileService),
      inboxController: InboxController(
        userId: profile.id,
        inboxService: inboxService,
        enableRealtime: false,
        enableInboxLoads: !profile.isGroup,
      ),
      profile: profile,
    ).._lastKnownRefreshToken = refreshToken;
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
