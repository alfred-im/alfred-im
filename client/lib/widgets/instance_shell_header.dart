// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

import '../models/profile_summary.dart';
import '../runtime/instance_runtime.dart';
import 'account_shell_header.dart';

/// Header guscio con nome/logo dell'istanza (non del software Alfred).
class InstanceShellHeader extends StatelessWidget {
  const InstanceShellHeader({
    super.key,
    required this.titleStyle,
    this.backgroundColor,
    this.padding = const EdgeInsets.fromLTRB(12, 12, 4, 0),
    this.showBackButton = false,
    this.onBack,
    this.drawerProfile,
    this.onDrawerTap,
    this.actions = const [],
  });

  final TextStyle titleStyle;
  final Color? backgroundColor;
  final EdgeInsetsGeometry padding;
  final bool showBackButton;
  final VoidCallback? onBack;
  final ProfileSummary? drawerProfile;
  final VoidCallback? onDrawerTap;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final runtime = InstanceRuntime.require;
    final logoUrl = runtime.branding.logoUrl;

    return AccountShellHeader(
      title: runtime.displayName,
      titleStyle: titleStyle,
      backgroundColor: backgroundColor,
      padding: padding,
      showBackButton: showBackButton,
      onBack: onBack,
      drawerProfile: drawerProfile,
      onDrawerTap: onDrawerTap,
      actions: actions,
      leading: logoUrl != null && logoUrl.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  logoUrl,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            )
          : null,
    );
  }
}
