import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_peer.dart';
import '../providers/auth_controller.dart';
import '../providers/inbox_controller.dart';
import '../providers/messages_controller.dart';
import '../services/compose_service.dart';
import '../theme/alfred_colors.dart';
import '../widgets/account_sidebar.dart';
import '../widgets/chat_panel.dart';
import '../widgets/inbox_panel.dart';
import 'contacts_screen.dart';
import 'auth_screen.dart';
import 'profile_screen.dart';

/// Layout principale stile WhatsApp Web: sidebar (profilo + inbox) + chat.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _composeService = ComposeService();
  ChatPeer? _activePeer;
  bool _showListOnMobile = true;

  static const _breakpoint = 720.0;

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  void _closeDrawer() => _scaffoldKey.currentState?.closeDrawer();

  Future<void> _openContacts() async {
    _closeDrawer();
    final peer = await Navigator.push<ChatPeer>(
      context,
      MaterialPageRoute(builder: (_) => const ContactsScreen()),
    );
    if (!mounted || peer == null) return;
    _openPeer(peer);
  }

  Future<void> _startMessageFromAddress(String address) async {
    try {
      final peer = await _composeService.resolveAddress(address);
      if (!mounted) return;
      _openPeer(peer);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('StateError: ', ''))),
      );
    }
  }

  void _openPeer(ChatPeer peer) {
    setState(() {
      _activePeer = peer;
      _showListOnMobile = false;
    });
  }

  void _selectInboxPeer(ChatPeer peer) {
    setState(() {
      _activePeer = peer;
      _showListOnMobile = false;
    });
  }

  Future<void> _onMessagesChanged() async {
    if (!mounted) return;
    final inbox = context.read<InboxController?>();
    if (inbox == null || _activePeer == null) return;

    await inbox.load();
    if (!mounted) return;

    final updated = inbox.findByProfileId(_activePeer!.profileId);
    if (updated != null) {
      setState(() {
        _activePeer = _activePeer!.mergeFromInbox(updated);
      });
    }
  }

  Future<void> _openProfile() async {
    _closeDrawer();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  Future<void> _openAddAccount() async {
    _closeDrawer();
    final auth = context.read<AuthController>();
    final navigator = Navigator.of(context);
    await auth.prepareAddAccount();
    await navigator.push<void>(
      MaterialPageRoute(
        builder: (routeCtx) => AuthScreen(
          addingAccount: true,
          onCancel: () => Navigator.of(routeCtx).pop(),
        ),
      ),
    );
  }

  Widget _accountSidebar({bool compact = false}) {
    return AccountSidebar(
      compact: compact,
      onEditProfile: _openProfile,
      onAddAccount: _openAddAccount,
      onAccountSwitched: () {
        _closeDrawer();
        setState(() {
          _activePeer = null;
          _showListOnMobile = true;
        });
      },
    );
  }

  Widget _inboxPanel({
    required InboxController inbox,
    required bool showDrawerButton,
    bool showBackButton = false,
    bool showTopBar = true,
    VoidCallback? onBack,
  }) {
    return InboxPanel(
      selectedPeerId: _activePeer?.profileId,
      peers: inbox.filteredPeers,
      isLoading: inbox.isLoading,
      error: inbox.error,
      onRetry: inbox.load,
      onSelected: _selectInboxPeer,
      onSearchChanged: inbox.setSearchQuery,
      onDrawerTap: showDrawerButton ? _openDrawer : null,
      onContactsTap: _openContacts,
      onNewMessage: _startMessageFromAddress,
      showBackButton: showBackButton,
      onBack: onBack,
      showTopBar: showTopBar,
    );
  }

  Widget _chatArea({
    required bool showBackButton,
    VoidCallback? onBack,
  }) {
    final peer = _activePeer;
    if (peer == null) {
      return const EmptyChatPlaceholder();
    }

    return _ChatWithMessages(
      key: ValueKey(peer.profileId),
      peer: peer,
      showBackButton: showBackButton,
      onBack: onBack,
      onMessagesChanged: _onMessagesChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final inbox = context.watch<InboxController?>();
    if (inbox == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= _breakpoint;
    final showChatOnMobile = _activePeer != null;
    final sidebarWidth = width >= 1100 ? 380.0 : 320.0;

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
                    _accountSidebar(compact: true),
                    const Divider(height: 1),
                    Expanded(
                      child: _inboxPanel(
                        inbox: inbox,
                        showDrawerButton: false,
                        showTopBar: false,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1, color: AlfredColors.border),
            Expanded(
              child: _chatArea(showBackButton: false),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        child: _accountSidebar(),
      ),
      body: !showChatOnMobile || _showListOnMobile
          ? _inboxPanel(
              inbox: inbox,
              showDrawerButton: true,
            )
          : _chatArea(
              showBackButton: true,
              onBack: () => setState(() => _showListOnMobile = true),
            ),
    );
  }
}

class _ChatWithMessages extends StatelessWidget {
  const _ChatWithMessages({
    super.key,
    required this.peer,
    this.showBackButton = false,
    this.onBack,
    required this.onMessagesChanged,
  });

  final ChatPeer peer;
  final bool showBackButton;
  final VoidCallback? onBack;
  final Future<void> Function() onMessagesChanged;

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthController>().userId!;

    return ChangeNotifierProvider(
      create: (_) => MessagesController(
        userId: userId,
        peerProfileId: peer.profileId,
        onMessagesChanged: onMessagesChanged,
      ),
      child: ChatPanel(
        peer: peer,
        showBackButton: showBackButton,
        onBack: onBack,
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
