// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

import '../models/profile_summary.dart';
import 'profile_identity.dart';

/// Header guscio account — inbox personale (scuro) e home gruppo (chiaro).
class AccountShellHeader extends StatelessWidget {
  const AccountShellHeader({
    super.key,
    required this.title,
    required this.titleStyle,
    this.titleWidget,
    this.backgroundColor,
    this.padding = const EdgeInsets.fromLTRB(12, 12, 4, 0),
    this.showBackButton = false,
    this.onBack,
    this.drawerProfile,
    this.onDrawerTap,
    this.leading,
    this.actions = const [],
  });

  final String title;
  final TextStyle titleStyle;
  final Widget? titleWidget;
  final Color? backgroundColor;
  final EdgeInsetsGeometry padding;
  final bool showBackButton;
  final VoidCallback? onBack;
  final ProfileSummary? drawerProfile;
  final VoidCallback? onDrawerTap;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final header = Padding(
      padding: padding,
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (showBackButton)
              IconButton(
                onPressed: onBack,
                icon: Icon(
                  Icons.arrow_back,
                  color: titleStyle.color,
                ),
              ),
            if (onDrawerTap != null && drawerProfile != null)
              AccountDrawerTrigger(
                profile: drawerProfile!,
                onTap: onDrawerTap!,
              ),
            ?leading,
            Expanded(
              child: titleWidget ??
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
            ),
            ...actions,
          ],
        ),
      ),
    );

    if (backgroundColor == null) {
      return header;
    }

    return ColoredBox(
      color: backgroundColor!,
      child: header,
    );
  }
}
