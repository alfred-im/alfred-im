// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

import '../runtime/instance_runtime.dart';
import 'alfred_logo.dart';

/// Logo istanza se configurato, altrimenti marchio software generico.
class InstanceBrandMark extends StatelessWidget {
  const InstanceBrandMark({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    final logoUrl = InstanceRuntime.require.branding.logoUrl;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.2),
        child: Image.network(
          logoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              AlfredLogo(size: size),
        ),
      );
    }
    return AlfredLogo(size: size);
  }
}
