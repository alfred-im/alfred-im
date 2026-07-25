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
import '../services/account_session.dart';
import '../services/supabase_bootstrap.dart';
import 'screens/app_shell.dart';
import 'theme/alfred_theme.dart';

Future<void> main() async {
  await bootstrapApp();
  runApp(const AlfredApp());
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
            contactService: session.contactService,
          ),
          keepPrevious: (previous, session) =>
              previous.ownerId == session.userId,
        ),
        focusScopedProvider<ReceptionAllowlistController>(
          create: (session, _) => ReceptionAllowlistController(
            ownerId: session.userId,
            allowlistService: session.receptionAllowlistService,
          ),
          keepPrevious: (previous, session) =>
              previous.ownerId == session.userId,
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
        title: 'Alfred',
        debugShowCheckedModeBanner: false,
        theme: AlfredTheme.light,
        home: const AppShell(),
      ),
    );
  }
}
