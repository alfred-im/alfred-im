// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_peer.dart';
import '../models/conversation_scope.dart';
import '../models/profile_summary.dart';
import '../providers/auth_controller.dart';
import '../providers/inbox_controller.dart';
import '../providers/messages_controller.dart';
import '../services/account_session.dart';
import '../theme/alfred_colors.dart';
import '../widgets/account_sidebar.dart';
import '../widgets/auth_overlay.dart';
import '../widgets/chat_panel.dart';
import '../widgets/no_account_placeholder.dart';
import '../widgets/inbox_panel.dart';
import '../widgets/group_home_panel.dart';
import '../providers/group_home_controller.dart';
import 'allowed_people_screen.dart';
import 'contacts_screen.dart';
import 'profile_screen.dart';
import 'group_conversation_screen.dart';
import '../utils/session_scope_keys.dart';

/// Layout principale stile WhatsApp Web: sidebar (profilo + inbox) + chat.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _breakpoint = 720.0;

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  void _closeDrawer() => _scaffoldKey.currentState?.closeDrawer();

  Future<void> _openAllowedPeople() async {
    _closeDrawer();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const AllowedPeopleScreen()),
    );
  }

  Future<void> _openContacts() async {
    _closeDrawer();
    final auth = context.read<AuthController>();
    final peer = await Navigator.push<ChatPeer>(
      context,
      MaterialPageRoute(builder: (_) => const ContactsScreen()),
    );
    if (!mounted || peer == null) return;
    auth.openConversation(peer);
  }

  Future<void> _startMessageFromAddress(String address) async {
    final auth = context.read<AuthController>();
    final session = auth.focusedSession;
    if (session == null) return;

    try {
      final peer = await session.composeService.resolveAddress(address);
      if (!mounted) return;
      auth.openConversation(peer);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('StateError: ', ''))),
      );
    }
  }

  Future<void> _onMessagesChanged() async {
    if (!mounted) return;
    final auth = context.read<AuthController>();
    final inbox = auth.focusedSession?.inboxController;
    final activePeer = auth.activePeer;
    if (inbox == null || activePeer == null) return;

    await inbox.load();
    if (!mounted) return;

    final updated = inbox.findByProfileId(activePeer.profileId);
    if (updated != null) {
      auth.mergeActivePeerFromInbox(updated);
    }
  }

  Future<void> _onGroupMessagesChangedFrom(
    BuildContext providerContext,
  ) async {
    if (!mounted) return;
    await providerContext.read<GroupHomeController>().reload();
  }

  Future<void> _openProfile() async {
    _closeDrawer();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  void _openAddAccount(BuildContext context) {
    _closeDrawer();
    context.read<AuthController>().openAuthOverlay(dismissible: true);
  }

  Widget _accountSidebar(BuildContext context, {bool compact = false}) {
    return AccountSidebar(
      compact: compact,
      onEditProfile: _openProfile,
      onAddAccount: () => _openAddAccount(context),
      onAccountSwitched: _closeDrawer,
    );
  }

  Widget _inboxPanel({
    required BuildContext context,
    required AuthController auth,
    required InboxController inbox,
    required String accountUserId,
    required bool showDrawerButton,
    bool showBackButton = false,
    bool showTopBar = true,
    VoidCallback? onBack,
  }) {
    return InboxPanel(
      key: ValueKey(accountUserId),
      selectedPeerId: auth.activePeer?.profileId,
      peers: inbox.filteredPeers,
      isLoading: inbox.isLoading,
      error: inbox.error,
      onRetry: inbox.load,
      onSelected: auth.openConversation,
      onSearchChanged: inbox.setSearchQuery,
      onDrawerTap: showDrawerButton ? _openDrawer : null,
      onContactsTap: _openContacts,
      onAllowedPeopleTap: _openAllowedPeople,
      onNewMessage: _startMessageFromAddress,
      showBackButton: showBackButton,
      onBack: onBack,
      showTopBar: showTopBar,
    );
  }

  Widget _chatArea({
    required AuthController auth,
    required AccountSession? session,
    required bool showBackButton,
    VoidCallback? onBack,
  }) {
    final peer = auth.activePeer;
    if (peer == null || session == null) {
      return const EmptyChatPlaceholder();
    }

    final scope = ConversationScope.fromSession(session, peer);
    if (!auth.isConversationReady(
      session: session,
      peer: peer,
    )) {
      return const ColoredBox(
        color: AlfredColors.surface,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return _ChatWithMessages(
      key: conversationScopeKey(scope),
      auth: auth,
      session: session,
      peer: peer,
      scope: scope,
      showBackButton: showBackButton,
      onBack: onBack,
      onMessagesChanged: _onMessagesChanged,
    );
  }

  Widget _mainContent(BuildContext context) {
    final auth = context.watch<AuthController>();
    final session = auth.focusedSession;
    final inbox = session?.inboxController;
    final accountUserId = session?.userId;
    final isGroupAccount = session?.profile.isGroup ?? false;

    if (isGroupAccount && session != null) {
      return ChangeNotifierProvider(
        key: groupSessionKey(session, 'group-home'),
        create: (_) => GroupHomeController(
          session: session,
          profile: session.profile,
          messageService: session.messageService,
          profileService: session.profileService,
        ),
        child: _GroupAccountLayout(
          session: session,
          auth: auth,
          scaffoldKey: _scaffoldKey,
          accountSidebar: _accountSidebar,
          onOpenProfile: _openProfile,
          onOpenAllowedPeople: _openAllowedPeople,
          onOpenDrawer: _openDrawer,
          onGroupMessagesChanged: _onGroupMessagesChangedFrom,
        ),
      );
    }

    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= _breakpoint;
    final showChatOnMobile = auth.activePeer != null;
    final sidebarWidth = width >= 1100 ? 380.0 : 320.0;

    final inboxArea = !auth.hasOpenAccounts
        ? const NoAccountPlaceholder()
        : session == null
            ? const _ReconnectingAccountPlaceholder()
            : ListenableBuilder(
            key: ValueKey(accountUserId),
            listenable: inbox!,
            builder: (context, _) => _inboxPanel(
              context: context,
              auth: auth,
              inbox: inbox,
              accountUserId: accountUserId!,
              showDrawerButton: !isWide,
              showTopBar: !isWide,
            ),
          );

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: sidebarWidth,
              child: ColoredBox(
                color: AlfredColors.panel,
                child: Column(
                  children: [
                    _accountSidebar(context, compact: true),
                    const Divider(height: 1),
                    Expanded(child: inboxArea),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1, color: AlfredColors.border),
            Expanded(
              child: _chatArea(
                auth: auth,
                session: session,
                showBackButton: false,
              ),
            ),
          ],
        ),
      );
    }

    final needsSessionRecovery =
        auth.hasOpenAccounts && session == null;

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        child: _accountSidebar(context),
      ),
      appBar: needsSessionRecovery
          ? AppBar(
              backgroundColor: AlfredColors.panel,
              foregroundColor: AlfredColors.textPrimary,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Account',
                onPressed: _openDrawer,
              ),
              title: const Text('Riconnessione…'),
            )
          : null,
      body: !showChatOnMobile || auth.showInboxOnMobile
          ? inboxArea
          : _chatArea(
              auth: auth,
              session: session,
              showBackButton: true,
              onBack: auth.backToInboxOnMobile,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Stack(
      children: [
        _mainContent(context),
        if (auth.showAuthOverlay) const AuthOverlay(),
      ],
    );
  }
}

/// Manifest con account ma sessione non ancora in RAM: riconnette invece del placeholder.
class _ReconnectingAccountPlaceholder extends StatefulWidget {
  const _ReconnectingAccountPlaceholder();

  @override
  State<_ReconnectingAccountPlaceholder> createState() =>
      _ReconnectingAccountPlaceholderState();
}

class _ReconnectingAccountPlaceholderState
    extends State<_ReconnectingAccountPlaceholder> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<AuthController>().reconnectFocusedSession());
    });
  }

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AlfredColors.surface,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _GroupAccountLayout extends StatelessWidget {
  const _GroupAccountLayout({
    required this.session,
    required this.auth,
    required this.scaffoldKey,
    required this.accountSidebar,
    required this.onOpenProfile,
    required this.onOpenAllowedPeople,
    required this.onOpenDrawer,
    required this.onGroupMessagesChanged,
  });

  static const _breakpoint = 720.0;

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
    final isWide = width >= _breakpoint;
    final sidebarWidth = width >= 1100 ? 380.0 : 320.0;

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
            key: groupSessionKey(session, 'group-chat-wide'),
            session: session,
            profile: session.profile,
            showBackButton: !isWide,
            onBack: auth.backToGroupHome,
            onMessagesChanged: onGroupMessagesChanged,
          )
        : const EmptyChatPlaceholder();

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: sidebarWidth,
              child: ColoredBox(
                color: AlfredColors.panel,
                child: Column(
                  children: [
                    accountSidebar(context, compact: true),
                    const Divider(height: 1),
                    Expanded(child: groupHomeArea),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1, color: AlfredColors.border),
            Expanded(child: groupChatArea),
          ],
        ),
      );
    }

    return Scaffold(
      key: scaffoldKey,
      drawer: Drawer(
        child: accountSidebar(context),
      ),
      body: auth.groupChatOpen
          ? _GroupChatWithMessages(
              key: groupSessionKey(session, 'group-chat-mobile'),
              session: session,
              profile: session.profile,
              showBackButton: true,
              onBack: auth.backToGroupHome,
              onMessagesChanged: onGroupMessagesChanged,
            )
          : groupHomeArea,
    );
  }
}

class _GroupChatWithMessages extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GroupConversationScreen(
      session: session,
      profile: profile,
      showBackButton: showBackButton,
      onBack: onBack,
      onMessagesChanged: () => onMessagesChanged(context),
    );
  }
}

class _ChatWithMessages extends StatelessWidget {
  const _ChatWithMessages({
    super.key,
    required this.auth,
    required this.session,
    required this.peer,
    required this.scope,
    this.showBackButton = false,
    this.onBack,
    required this.onMessagesChanged,
  });

  final AuthController auth;
  final AccountSession session;
  final ChatPeer peer;
  final ConversationScope scope;
  final bool showBackButton;
  final VoidCallback? onBack;
  final Future<void> Function() onMessagesChanged;

  bool _focusedSessionValid() {
    final live = auth.focusedSession;
    return live != null && live.userId == session.userId && live.hasValidJwt();
  }

  @override
  Widget build(BuildContext context) {
    final liveSession = auth.focusedSession;
    if (liveSession == null ||
        liveSession.userId != session.userId ||
        !scope.matches(liveSession, peer) ||
        !auth.isConversationReady(
          session: liveSession,
          peer: peer,
        )) {
      return const ColoredBox(
        color: AlfredColors.surface,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => MessagesController(
        scope: scope,
        userId: liveSession.userId,
        peerProfileId: peer.profileId,
        messageService: liveSession.messageService,
        messageMediaService: liveSession.messageMediaService,
        inboxService: liveSession.inboxService,
        profileService: liveSession.profileService,
        peerIsGroup: peer.isGroup,
        onMessagesChanged: onMessagesChanged,
        hasValidSession: _focusedSessionValid,
        isScopeCommitted: () {
          final live = auth.focusedSession;
          final active = auth.activePeer;
          if (live == null || active == null) return false;
          return auth.isConversationReady(
            session: live,
            peer: active,
          );
        },
      ),
      child: ChatPanel(
        peer: peer,
        showBackButton: showBackButton,
        onBack: onBack,
        showAuthorLabels: peer.isGroup,
      ),
    );
  }
}

class EmptyChatPlaceholder extends StatelessWidget {
  const EmptyChatPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AlfredColors.surface,
      child: Center(
        child: Text(
          'Seleziona una chat o scrivi a un indirizzo',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AlfredColors.textSecondary,
              ),
        ),
      ),
    );
  }
}
