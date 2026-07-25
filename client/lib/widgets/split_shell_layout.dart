// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

import '../theme/alfred_colors.dart';

/// Wide Row (sidebar + detail) vs mobile Scaffold with drawer (breakpoint 720).
class SplitShellLayout extends StatelessWidget {
  const SplitShellLayout({
    super.key,
    required this.scaffoldKey,
    required this.accountSidebar,
    required this.primaryPane,
    required this.detailPane,
    required this.showDetailOnMobile,
    this.mobileAppBar,
  });

  static const double breakpoint = 720.0;

  final GlobalKey<ScaffoldState> scaffoldKey;
  final Widget Function(BuildContext context, {bool compact}) accountSidebar;
  final Widget primaryPane;
  final Widget detailPane;
  final bool showDetailOnMobile;
  final PreferredSizeWidget? mobileAppBar;

  static double sidebarWidthFor(double screenWidth) =>
      screenWidth >= 1100 ? 380.0 : 320.0;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= breakpoint;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: sidebarWidthFor(width),
              child: ColoredBox(
                color: AlfredColors.panel,
                child: Column(
                  children: [
                    accountSidebar(context, compact: true),
                    const Divider(height: 1),
                    Expanded(child: primaryPane),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1, color: AlfredColors.border),
            Expanded(child: detailPane),
          ],
        ),
      );
    }

    return Scaffold(
      key: scaffoldKey,
      drawer: Drawer(
        child: accountSidebar(context),
      ),
      appBar: mobileAppBar,
      body: showDetailOnMobile ? detailPane : primaryPane,
    );
  }
}
