// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_controller.dart';
import '../providers/contacts_controller.dart';
import '../providers/profile_controller.dart';
import '../providers/reception_allowlist_controller.dart';
import '../providers/shareable_link_controller.dart';
import '../runtime/instance_runtime.dart';
import '../screens/app_shell.dart';
import '../screens/deploy_config_error_screen.dart';
import '../services/account_session.dart';
import '../services/supabase_bootstrap.dart';
import '../theme/alfred_theme.dart';

Future<void> main() async {
  await runAppWithDeployConfig(
    bootstrapApp,
    () => const AlfredApp(),
  );
}

/// Rebuilds a session-scoped [ChangeNotifier] when focus changes.
ChangeNotifierProxyProvider<AuthController, T?>
    focusScopedProvider<T extends ChangeNotifier>({
  required T Function(AccountSession session, AuthController auth) create,
  required bool Function(T previous, AccountSession session) keepPrevious,
}) {
  return ChangeNotifierProxyProvider<AuthController, T?>(
    create: (_) => null,
    update: (_, auth, previous) {
      if (!auth.sessionReady) return null;
      final session = auth.focusedSession;
      if (session == null) return null;
      if (previous != null && keepPrevious(previous, session)) {
        return previous;
      }
      return create(session, auth);
    },
  );
}

class AlfredApp extends StatelessWidget {
  const AlfredApp({super.key});

  @override
  Widget build(BuildContext context) {
    final runtime = InstanceRuntime.require;
    final themeColor = _parseThemeColor(runtime.branding.themeColor);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthController()..initialize(),
        ),
        ChangeNotifierProvider(
          create: (_) => ShareableLinkController(),
        ),
        focusScopedProvider<ContactsController>(
          create: (session, _) => ContactsController(
            ownerId: session.userId,
            sessionEpoch: session.epoch,
            contactService: session.contactService,
          ),
          keepPrevious: (previous, session) =>
              previous.ownerId == session.userId &&
              previous.sessionEpoch == session.epoch,
        ),
        focusScopedProvider<ReceptionAllowlistController>(
          create: (session, _) => ReceptionAllowlistController(
            ownerId: session.userId,
            sessionEpoch: session.epoch,
            allowlistService: session.receptionAllowlistService,
          ),
          keepPrevious: (previous, session) =>
              previous.ownerId == session.userId &&
              previous.sessionEpoch == session.epoch,
        ),
        focusScopedProvider<ProfileController>(
          create: (session, auth) => ProfileController(
            userId: session.userId,
            profileService: session.profileService,
            avatarService: session.profileAvatarService,
            onRefreshAuthProfile: auth.refreshProfile,
          ),
          keepPrevious: (previous, session) =>
              previous.userId == session.userId,
        ),
      ],
      child: MaterialApp(
        title: runtime.displayName,
        debugShowCheckedModeBanner: false,
        theme: AlfredTheme.light.copyWith(
          colorScheme: themeColor != null
              ? AlfredTheme.light.colorScheme.copyWith(primary: themeColor)
              : null,
        ),
        home: const AppShell(),
      ),
    );
  }

  Color? _parseThemeColor(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final normalized = raw.replaceFirst('#', '');
    if (normalized.length != 6) return null;
    final value = int.tryParse(normalized, radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 | value);
  }
}
