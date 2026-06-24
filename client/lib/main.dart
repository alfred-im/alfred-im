import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/auth_controller.dart';
import '../providers/contacts_controller.dart';
import '../providers/conversations_controller.dart';
import '../providers/profile_controller.dart';
import '../services/supabase_bootstrap.dart';
import 'screens/app_shell.dart';
import 'theme/alfred_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrapSupabase();
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
        ProxyProvider<AuthController, ConversationsController?>(
          update: (_, auth, previous) {
            final userId = auth.userId;
            if (userId == null) return null;
            if (previous?.userId == userId) return previous;
            return ConversationsController(userId: userId);
          },
        ),
        ProxyProvider<AuthController, ContactsController?>(
          update: (_, auth, previous) {
            final userId = auth.userId;
            if (userId == null) return null;
            if (previous?.ownerId == userId) return previous;
            return ContactsController(ownerId: userId);
          },
        ),
        ProxyProvider<AuthController, ProfileController?>(
          update: (_, auth, previous) {
            final userId = auth.userId;
            if (userId == null) return null;
            if (previous?.userId == userId) return previous;
            return ProfileController(userId: userId);
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

// ignore: unused_element
void _assertConfig() {
  assert(AppConfig.supabaseUrl.isNotEmpty);
  assert(AppConfig.supabaseAnonKey.isNotEmpty);
}
