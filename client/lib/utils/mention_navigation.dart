// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_controller.dart';
import '../screens/shareable_link_not_found_screen.dart';

/// Tap su `@username` in bolla → chat 1:1 o risorsa non trovata.
Future<void> openChatFromMentionUsername(
  BuildContext context,
  String username,
) async {
  final auth = context.read<AuthController>();
  final session = auth.focusedSession;
  if (session == null) return;

  try {
    final peer = await session.composeService.resolveAddress(username);
    if (!context.mounted) return;
    await auth.openConversation(peer);
  } on StateError catch (e) {
    if (!context.mounted) return;
    final message = e.toString().replaceFirst('StateError: ', '');
    if (message == 'Utente non trovato') {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (ctx) => ShareableLinkNotFoundScreen(
            onDismiss: () => Navigator.of(ctx).pop(),
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
