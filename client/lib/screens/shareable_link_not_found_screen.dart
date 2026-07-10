import 'package:flutter/material.dart';

import '../theme/alfred_colors.dart';

/// Risorsa link non trovata (404).
class ShareableLinkNotFoundScreen extends StatelessWidget {
  const ShareableLinkNotFoundScreen({
    super.key,
    required this.onDismiss,
  });

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AlfredColors.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.link_off_outlined,
                  size: 56,
                  color: AlfredColors.textSecondary.withValues(alpha: 0.8),
                ),
                const SizedBox(height: 20),
                Text(
                  'Risorsa non trovata',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AlfredColors.charcoal,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Questo indirizzo non esiste o non è disponibile su questa istanza.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AlfredColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: onDismiss,
                  style: FilledButton.styleFrom(
                    backgroundColor: AlfredColors.charcoal,
                    foregroundColor: AlfredColors.textOnDark,
                  ),
                  child: const Text('Torna all\'app'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
