import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_peer.dart';
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
import 'contacts_screen.dart';
import 'profile_screen.dart';

/// Layout principale stile WhatsApp Web: sidebar (profilo + inbox) + chat.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
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
    final session = context.read<AuthController>().focusedSession;
    if (session == null) return;

    try {
      final peer = await session.composeService.resolveAddress(address);
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

  void _openAddAccount() {
    _closeDrawer();
    context.read<AuthController>().openAuthOverlay(dismissible: true);
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
    required String accountUserId,
    required bool showDrawerButton,
    bool showBackButton = false,
    bool showTopBar = true,
    VoidCallback? onBack,
  }) {
    return InboxPanel(
      key: ValueKey(accountUserId),
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
    required AccountSession? session,
    required bool showBackButton,
    VoidCallback? onBack,
  }) {
    final peer = _activePeer;
    if (peer == null || session == null) {
      return const EmptyChatPlaceholder();
    }

    return _ChatWithMessages(
      key: ValueKey('${session.userId}-${peer.profileId}'),
      session: session,
      peer: peer,
      showBackButton: showBackButton,
      onBack: onBack,
      onMessagesChanged: _onMessagesChanged,
    );
  }

  Widget _mainContent() {
    final auth = context.watch<AuthController>();
    final inbox = context.watch<InboxController?>();
    final session = auth.focusedSession;
    final accountUserId = session?.userId;

    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= _breakpoint;
    final showChatOnMobile = _activePeer != null;
    final sidebarWidth = width >= 1100 ? 380.0 : 320.0;

    final inboxArea = accountUserId != null && inbox != null
        ? _inboxPanel(
            inbox: inbox,
            accountUserId: accountUserId,
            showDrawerButton: !isWide,
            showTopBar: !isWide,
          )
        : const NoAccountPlaceholder();

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
                    Expanded(child: inboxArea),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1, color: AlfredColors.border),
            Expanded(
              child: _chatArea(session: session, showBackButton: false),
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
          ? inboxArea
          : _chatArea(
              session: session,
              showBackButton: true,
              onBack: () => setState(() => _showListOnMobile = true),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Stack(
      children: [
        _mainContent(),
        if (auth.showAuthOverlay) const AuthOverlay(),
      ],
    );
  }
}

class _ChatWithMessages extends StatelessWidget {
  const _ChatWithMessages({
    super.key,
    required this.session,
    required this.peer,
    this.showBackButton = false,
    this.onBack,
    required this.onMessagesChanged,
  });

  final AccountSession session;
  final ChatPeer peer;
  final bool showBackButton;
  final VoidCallback? onBack;
  final Future<void> Function() onMessagesChanged;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MessagesController(
        userId: session.userId,
        peerProfileId: peer.profileId,
        expectInboxHistory: peer.hasInboxHistory,
        messageService: session.messageService,
        messageMediaService: session.messageMediaService,
        inboxService: session.inboxService,
        onMessagesChanged: onMessagesChanged,
        onInboxResync: () async {
          await session.inboxController.load();
        },
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
