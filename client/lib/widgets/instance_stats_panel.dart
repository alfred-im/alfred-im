// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

import '../models/instance_stats.dart';
import '../theme/alfred_colors.dart';

/// Pannello statistiche istanza (solo owner), tra header e lista inbox.
class InstanceStatsPanel extends StatelessWidget {
  const InstanceStatsPanel({
    super.key,
    required this.stats,
    this.isLoading = false,
    this.error,
    this.onRetry,
  });

  final InstanceStats? stats;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading && stats == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (error != null && stats == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Statistiche non disponibili',
                style: TextStyle(
                  color: AlfredColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Riprova')),
          ],
        ),
      );
    }

    final data = stats;
    if (data == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AlfredColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AlfredColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statistiche server',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AlfredColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatChip(
                label: 'Account',
                value: '${data.totalUserAccounts}',
              ),
              _StatChip(label: 'Gruppi', value: '${data.totalGroups}'),
              _StatChip(
                label: 'Attivi 30g',
                value: '${data.activeAccounts30d}',
              ),
              _StatChip(
                label: 'Messaggi 7g',
                value: _formatCount(data.messagesLast7Days),
              ),
              if (data.disabledAccounts > 0)
                _StatChip(
                  label: 'Disattivati',
                  value: '${data.disabledAccounts}',
                  highlight: true,
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return '$value';
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight
            ? AlfredColors.unreadBadge.withValues(alpha: 0.12)
            : AlfredColors.panel,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: TextStyle(
              fontSize: 12,
              color: highlight
                  ? AlfredColors.unreadBadge
                  : AlfredColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: highlight
                  ? AlfredColors.unreadBadge
                  : AlfredColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
