// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

import '../models/profile_summary.dart';
import '../runtime/instance_runtime.dart';
import 'account_shell_header.dart';

/// Header guscio con nome/wordmark dell'istanza (non del software Alfred).
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
    final wordmarkUrl = runtime.branding.wordmarkUrl;
    final displayName = runtime.displayName;

    Widget? titleWidget;
    if (wordmarkUrl != null && wordmarkUrl.isNotEmpty) {
      final height = (titleStyle.fontSize ?? 20) * 1.2;
      titleWidget = Semantics(
        label: displayName,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Image.network(
            wordmarkUrl,
            height: height,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            errorBuilder: (context, error, stackTrace) => Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: titleStyle,
            ),
          ),
        ),
      );
    }

    return AccountShellHeader(
      title: displayName,
      titleStyle: titleStyle,
      titleWidget: titleWidget,
      backgroundColor: backgroundColor,
      padding: padding,
      showBackButton: showBackButton,
      onBack: onBack,
      drawerProfile: drawerProfile,
      onDrawerTap: onDrawerTap,
      actions: actions,
    );
  }
}
