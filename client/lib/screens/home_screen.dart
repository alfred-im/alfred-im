import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/conversation.dart';
import '../providers/auth_controller.dart';
import '../providers/conversations_controller.dart';
import '../providers/messages_controller.dart';
import '../theme/alfred_colors.dart';
import '../widgets/account_sidebar.dart';
import '../widgets/chat_panel.dart';
import '../widgets/conversations_panel.dart';
import 'contacts_screen.dart';
import 'auth_screen.dart';
import 'profile_screen.dart';

/// Layout principale stile WhatsApp Web: sidebar (profilo + conversazioni) + chat.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _selectedId;
  bool _showListOnMobile = true;

  static const _breakpoint = 720.0;

  Conversation? _findSelected(ConversationsController controller) {
    final id = _selectedId;
    if (id == null) return null;
    for (final c in controller.conversations) {
      if (c.id == id) return c;
    }
    return null;
  }

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  void _closeDrawer() => _scaffoldKey.currentState?.closeDrawer();

  Future<void> _openContacts() async {
    _closeDrawer();
    final conversationId = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ContactsScreen()),
    );
    if (!mounted) return;
    await context.read<ConversationsController?>()?.load();
    if (conversationId != null) {
      setState(() {
        _selectedId = conversationId;
        _showListOnMobile = false;
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
          _selectedId = null;
          _showListOnMobile = true;
        });
      },
    );
  }

  Widget _conversationsPanel({
    required ConversationsController conversations,
    required bool showDrawerButton,
    bool showBackButton = false,
    bool showTopBar = true,
    VoidCallback? onBack,
  }) {
    return ConversationsPanel(
      selectedId: _selectedId,
      conversations: conversations.filteredConversations,
      isLoading: conversations.isLoading,
      error: conversations.error,
      onRetry: conversations.load,
      onSelected: (id) => setState(() {
        _selectedId = id;
        _showListOnMobile = false;
      }),
      onSearchChanged: conversations.setSearchQuery,
      onDrawerTap: showDrawerButton ? _openDrawer : null,
      onContactsTap: _openContacts,
      showBackButton: showBackButton,
      onBack: onBack,
      showTopBar: showTopBar,
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversations = context.watch<ConversationsController?>();
    if (conversations == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= _breakpoint;
    final selected = _findSelected(conversations);
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
                      child: _conversationsPanel(
                        conversations: conversations,
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
              child: selected == null
                  ? const EmptyChatPlaceholder()
                  : _ChatWithMessages(
                      key: ValueKey(selected.id),
                      conversation: selected,
                    ),
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
      body: selected == null || _showListOnMobile
          ? _conversationsPanel(
              conversations: conversations,
              showDrawerButton: true,
            )
          : _ChatWithMessages(
              key: ValueKey(selected.id),
              conversation: selected,
              showBackButton: true,
              onBack: () => setState(() => _showListOnMobile = true),
              onDrawerTap: _openDrawer,
            ),
    );
  }
}

class _ChatWithMessages extends StatelessWidget {
  const _ChatWithMessages({
    super.key,
    required this.conversation,
    this.showBackButton = false,
    this.onBack,
    this.onDrawerTap,
  });

  final Conversation conversation;
  final bool showBackButton;
  final VoidCallback? onBack;
  final VoidCallback? onDrawerTap;

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthController>().userId!;

    return ChangeNotifierProvider(
      create: (_) => MessagesController(
        conversationId: conversation.id,
        userId: userId,
      ),
      child: ChatPanel(
        conversation: conversation,
        showBackButton: showBackButton,
        onBack: onBack,
        onDrawerTap: onDrawerTap,
      ),
    );
  }
}
