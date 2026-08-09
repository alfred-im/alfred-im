// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/profile_summary.dart';
import '../providers/auth_controller.dart';
import '../services/account_session.dart';
import '../utils/session_scope_keys.dart';
import '../theme/alfred_colors.dart';
import '../widgets/conversation_scope_pane.dart';
import '../widgets/group_home_panel.dart';
import '../widgets/split_shell_layout.dart';
import 'group_conversation_screen.dart' deferred as group_chat;

/// Group-account shell: group home list + group chat detail.
class GroupAccountShell extends StatelessWidget {
  const GroupAccountShell({
    super.key,
    required this.session,
    required this.auth,
    required this.scaffoldKey,
    required this.accountSidebar,
    required this.onOpenProfile,
    required this.onOpenAllowedPeople,
    required this.onOpenDrawer,
    required this.onGroupMessagesChanged,
  });

  final AccountSession session;
  final AuthController auth;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final Widget Function(BuildContext context, {bool compact}) accountSidebar;
  final Future<void> Function() onOpenProfile;
  final Future<void> Function() onOpenAllowedPeople;
  final VoidCallback onOpenDrawer;
  final Future<void> Function(BuildContext providerContext) onGroupMessagesChanged;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= SplitShellLayout.breakpoint;

    final groupHomeArea = GroupHomePanel(
      profile: session.profile,
      conversationSelected: auth.groupChatOpen,
      onConversationTap: auth.openGroupChat,
      onProfileTap: () => unawaited(onOpenProfile()),
      onAllowedPeopleTap: () => unawaited(onOpenAllowedPeople()),
      onDrawerTap: isWide ? null : onOpenDrawer,
    );

    final groupChatArea = auth.groupChatOpen
        ? _GroupChatWithMessages(
            key: groupSessionKey(
              session,
              isWide ? 'group-chat-wide' : 'group-chat-mobile',
            ),
            session: session,
            profile: session.profile,
            showBackButton: !isWide,
            onBack: auth.backToGroupHome,
            onMessagesChanged: onGroupMessagesChanged,
          )
        : const EmptyChatPlaceholder();

    return SplitShellLayout(
      scaffoldKey: scaffoldKey,
      accountSidebar: accountSidebar,
      primaryPane: groupHomeArea,
      detailPane: groupChatArea,
      showDetailOnMobile: auth.groupChatOpen,
    );
  }
}

class _GroupChatWithMessages extends StatefulWidget {
  const _GroupChatWithMessages({
    super.key,
    required this.session,
    required this.profile,
    this.showBackButton = false,
    this.onBack,
    required this.onMessagesChanged,
  });

  final AccountSession session;
  final ProfileSummary profile;
  final bool showBackButton;
  final VoidCallback? onBack;
  final Future<void> Function(BuildContext providerContext) onMessagesChanged;

  @override
  State<_GroupChatWithMessages> createState() => _GroupChatWithMessagesState();
}

class _GroupChatWithMessagesState extends State<_GroupChatWithMessages> {
  late final Future<void> _library;

  @override
  void initState() {
    super.initState();
    _library = group_chat.loadLibrary();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _library,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ColoredBox(
            color: AlfredColors.surface,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const ColoredBox(
            color: AlfredColors.surface,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return group_chat.GroupConversationScreen(
          session: widget.session,
          profile: widget.profile,
          showBackButton: widget.showBackButton,
          onBack: widget.onBack,
          onMessagesChanged: () => widget.onMessagesChanged(context),
        );
      },
    );
  }
}
