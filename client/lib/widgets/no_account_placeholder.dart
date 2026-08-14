// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

import '../runtime/instance_runtime.dart';
import '../theme/alfred_colors.dart';
import 'instance_brand_mark.dart';

class NoAccountPlaceholder extends StatelessWidget {
  const NoAccountPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final serviceName = InstanceRuntime.require.displayName;

    return ColoredBox(
      color: AlfredColors.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const InstanceBrandMark(size: 48),
              const SizedBox(height: 16),
              Text(
                'Nessun account aperto',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Apri o crea un account su $serviceName per vedere le conversazioni.',
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
