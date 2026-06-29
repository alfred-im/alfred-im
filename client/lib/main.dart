import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_controller.dart';
import '../providers/contacts_controller.dart';
import '../providers/inbox_controller.dart';
import '../providers/profile_controller.dart';
import '../services/supabase_bootstrap.dart';
import 'screens/app_shell.dart';
import 'theme/alfred_theme.dart';

Future<void> main() async {
  await bootstrapApp();
  runApp(const AlfredApp());
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
        ListenableProxyProvider<AuthController, InboxController?>(
          create: (_) => null,
          update: (_, auth, _) {
            if (!auth.sessionReady) return null;
            return auth.focusedSession?.inboxController;
          },
          // InboxController è di proprietà di AccountSession (dispose in close()).
          // Non farlo smaltire dal Provider al cambio focus — altrimenti crash
          // multi-account ("used after being disposed").
          dispose: (context, inbox) {
            // Lifecycle gestito da AccountSession.close().
          },
        ),
        ChangeNotifierProxyProvider<AuthController, ContactsController?>(
          create: (_) => null,
          update: (_, auth, previous) {
            if (!auth.sessionReady) return null;
            final session = auth.focusedSession;
            if (session == null) return null;
            if (previous?.ownerId == session.userId) return previous;
            return ContactsController(
              ownerId: session.userId,
              contactService: session.contactService,
            );
          },
        ),
        ChangeNotifierProxyProvider<AuthController, ProfileController?>(
          create: (_) => null,
          update: (_, auth, previous) {
            if (!auth.sessionReady) return null;
            final session = auth.focusedSession;
            if (session == null) return null;
            if (previous?.userId == session.userId) return previous;
            return ProfileController(
              userId: session.userId,
              profileService: session.profileService,
              avatarService: session.profileAvatarService,
            );
          },
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
