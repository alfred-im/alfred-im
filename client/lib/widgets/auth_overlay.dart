import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_controller.dart';
import '../screens/auth_screen.dart';

/// Overlay semi-trasparente per aprire un account messaggistica.
class AuthOverlay extends StatelessWidget {
  const AuthOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AuthScreen(
                addingAccount: auth.hasOpenAccounts,
                onCancel: auth.authOverlayDismissible
                    ? () => auth.closeAuthOverlay()
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
