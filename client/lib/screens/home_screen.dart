import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/conversation.dart';
import '../providers/auth_controller.dart';
import '../providers/conversations_controller.dart';
import '../providers/messages_controller.dart';
import '../theme/alfred_colors.dart';
import '../widgets/chat_panel.dart';
import '../widgets/conversations_panel.dart';
import 'contacts_screen.dart';
import 'auth_screen.dart';
import 'profile_screen.dart';

/// Layout principale stile WhatsApp Web: lista + chat.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  Future<void> _openContacts() async {
    final conversationId = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ContactsScreen()),
    );
    if (conversationId != null && mounted) {
      setState(() {
        _selectedId = conversationId;
        _showListOnMobile = false;
      });
    }
  }

  Future<void> _openProfile() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  Future<void> _showAccountMenu() async {
    final auth = context.read<AuthController>();
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Account Alfred',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              ...auth.savedAccounts.map(
                (account) => ListTile(
                  leading: const Icon(Icons.account_circle_outlined),
                  title: Text(account.displayName),
                  subtitle: Text(account.email),
                  trailing: auth.userId == account.userId
                      ? const Icon(Icons.check, color: AlfredColors.unreadBadge)
                      : null,
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);
                    if (auth.userId != account.userId) {
                      final ok = await auth.switchAccount(account);
                      if (!ok && auth.error != null) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(auth.error!)),
                        );
                      }
                    }
                  },
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.person_add_alt_1_outlined),
                title: const Text('Aggiungi account'),
                onTap: () async {
                  final navigator = Navigator.of(context);
                  Navigator.pop(ctx);
                  await auth.prepareAddAccount();
                  await navigator.push<void>(
                    MaterialPageRoute(
                      builder: (routeCtx) => AuthScreen(
                        addingAccount: true,
                        onCancel: () => Navigator.of(routeCtx).pop(),
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Profilo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openProfile();
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Esci'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await auth.signOut();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversations = context.watch<ConversationsController>();
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= _breakpoint;
    final selected = _findSelected(conversations);

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: width >= 1100 ? 380 : 320,
              child: ConversationsPanel(
                selectedId: _selectedId,
                conversations: conversations.filteredConversations,
                isLoading: conversations.isLoading,
                onSelected: (id) => setState(() => _selectedId = id),
                onSearchChanged: conversations.setSearchQuery,
                onMenuTap: _showAccountMenu,
                onContactsTap: _openContacts,
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

    if (selected == null || _showListOnMobile) {
      return Scaffold(
        body: ConversationsPanel(
          selectedId: _selectedId,
          conversations: conversations.filteredConversations,
          isLoading: conversations.isLoading,
          onSelected: (id) => setState(() {
            _selectedId = id;
            _showListOnMobile = false;
          }),
          onSearchChanged: conversations.setSearchQuery,
          onMenuTap: _showAccountMenu,
          onContactsTap: _openContacts,
        ),
      );
    }

    return Scaffold(
      body: _ChatWithMessages(
        key: ValueKey(selected.id),
        conversation: selected,
        showBackButton: true,
        onBack: () => setState(() => _showListOnMobile = true),
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
  });

  final Conversation conversation;
  final bool showBackButton;
  final VoidCallback? onBack;

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
      ),
    );
  }
}
