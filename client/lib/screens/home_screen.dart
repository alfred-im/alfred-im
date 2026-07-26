// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_peer.dart';
import '../providers/auth_controller.dart';
import '../providers/inbox_controller.dart';
import '../providers/group_home_controller.dart';
import '../theme/alfred_colors.dart';
import '../widgets/account_sidebar.dart';
import '../widgets/auth_overlay.dart';
import '../widgets/no_account_placeholder.dart';
import '../widgets/inbox_panel.dart';
import '../widgets/conversation_scope_pane.dart';
import '../widgets/split_shell_layout.dart';
import '../utils/session_scope_keys.dart';
import 'allowed_people_screen.dart';
import 'contacts_screen.dart';
import 'profile_screen.dart';
import 'group_account_shell.dart';

/// Layout principale stile WhatsApp Web: sidebar (profilo + inbox) + chat.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

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
    auth.navigation.openConversation(peer);
  }

  Future<void> _startMessageFromAddress(String address) async {
    final auth = context.read<AuthController>();
    final session = auth.focusedSession;
    if (session == null) return;

    try {
      final peer = await session.composeService.resolveAddress(address);
      if (!mounted) return;
      auth.navigation.openConversation(peer);
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
      auth.navigation.mergeActivePeerFromInbox(updated);
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
      onSelected: auth.navigation.openConversation,
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

  Widget _mainContent(BuildContext context) {
    final auth = context.watch<AuthController>();
    final session = auth.focusedSession;
    final inbox = session?.inboxController;
    final accountUserId = session?.userId ?? auth.userId;
    final isGroupAccount =
        session?.profile.isGroup ?? auth.focusedProfileSummary?.isGroup ?? false;

    if (isGroupAccount && session != null) {
      return ChangeNotifierProvider(
        key: groupSessionKey(session, 'group-home'),
        create: (_) => GroupHomeController(
          session: session,
          profile: session.profile,
          messageService: session.messageService,
          profileService: session.profileService,
        ),
        child: GroupAccountShell(
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
    final isWide = width >= SplitShellLayout.breakpoint;
    final showChatOnMobile =
        auth.navigation.isChatShellOpen && auth.navigation.committedScope != null;

    final inboxArea = !auth.hasOpenAccounts
        ? const NoAccountPlaceholder()
        : session == null
            ? auth.isFocusedAccountDisconnected
                ? _DisconnectedAccountPlaceholder(
                    onReconnect: () => auth.promptReconnectFocusedAccount(),
                  )
                : const _ReconnectingAccountPlaceholder()
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

    final chatArea = ConversationScopePane(
      auth: auth,
      session: session,
      showBackButton: !isWide,
      onBack: isWide ? null : auth.navigation.backToInboxOnMobile,
      onMessagesChanged: _onMessagesChanged,
    );

    final needsSessionRecovery = auth.hasOpenAccounts && session == null;

    return SplitShellLayout(
      scaffoldKey: _scaffoldKey,
      accountSidebar: _accountSidebar,
      primaryPane: inboxArea,
      detailPane: chatArea,
      showDetailOnMobile: !auth.showInboxOnMobile && showChatOnMobile,
      mobileAppBar: needsSessionRecovery
          ? AppBar(
              backgroundColor: AlfredColors.panel,
              foregroundColor: AlfredColors.textPrimary,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Account',
                onPressed: _openDrawer,
              ),
              title: Text(
                auth.isFocusedAccountDisconnected
                    ? 'Disconnesso'
                    : 'Riconnessione…',
              ),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Stack(
      key: navigationShellKey(
        focusUserId: auth.userId,
        committedScope: auth.navigation.committedScope,
      ),
      children: [
        _mainContent(context),
        if (auth.showAuthOverlay) const AuthOverlay(),
      ],
    );
  }
}

/// Errore sessione: account resta nel manifest ma non è utilizzabile finché non si riaccede.
class _DisconnectedAccountPlaceholder extends StatelessWidget {
  const _DisconnectedAccountPlaceholder({required this.onReconnect});

  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AlfredColors.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.link_off_outlined,
                size: 48,
                color: AlfredColors.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                'Account disconnesso',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AlfredColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'La sessione non è più valida su questo dispositivo. '
                'L\'account resta nell\'elenco: accedi di nuovo per continuare.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AlfredColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onReconnect,
                child: const Text('Accedi di nuovo'),
              ),
            ],
          ),
        ),
      ),
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
