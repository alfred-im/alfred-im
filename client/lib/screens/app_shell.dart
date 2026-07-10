import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_controller.dart';
import '../providers/shareable_link_controller.dart';
import '../screens/shareable_link_not_found_screen.dart';
import '../widgets/shareable_link_listener.dart';
import 'home_screen.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final link = context.watch<ShareableLinkController>();

    return ShareableLinkListener(
      child: Builder(
        builder: (context) {
          if (!auth.sessionReady) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (link.notFound) {
            return ShareableLinkNotFoundScreen(
              onDismiss: () => link.dismissNotFound(),
            );
          }

          return const HomeScreen();
        },
      ),
    );
  }
}
