import 'package:flutter/material.dart';

import '../theme/alfred_colors.dart';
import 'alfred_logo.dart';

class NoAccountPlaceholder extends StatelessWidget {
  const NoAccountPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AlfredColors.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AlfredLogo(size: 48),
              const SizedBox(height: 16),
              Text(
                'Nessun account aperto',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Apri o crea un account Alfred per vedere le conversazioni.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AlfredColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
