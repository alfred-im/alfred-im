// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

import '../theme/alfred_colors.dart';

/// Pannello inline errore + pulsante «Riprova» (chat, home gruppo, ecc.).
class InlineErrorRetry extends StatelessWidget {
  const InlineErrorRetry({
    super.key,
    required this.message,
    required this.onRetry,
    this.icon,
    this.messageStyle,
    this.gapBeforeRetry = 16,
    this.retryWithIcon = false,
  });

  final String message;
  final VoidCallback onRetry;
  final IconData? icon;
  final TextStyle? messageStyle;
  final double gapBeforeRetry;
  final bool retryWithIcon;

  @override
  Widget build(BuildContext context) {
    final resolvedMessageStyle = messageStyle ??
        Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AlfredColors.textSecondary,
            );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 40,
                color: AlfredColors.textSecondary,
              ),
              const SizedBox(height: 12),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: resolvedMessageStyle,
            ),
            SizedBox(height: gapBeforeRetry),
            if (retryWithIcon)
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Riprova'),
              )
            else
              FilledButton(
                onPressed: onRetry,
                child: const Text('Riprova'),
              ),
          ],
        ),
      ),
    );
  }
}
