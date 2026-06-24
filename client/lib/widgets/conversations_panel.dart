import 'package:flutter/material.dart';

import '../models/conversation.dart';
import '../theme/alfred_colors.dart';
import 'conversation_tile.dart';

class ConversationsPanel extends StatefulWidget {
  const ConversationsPanel({
    super.key,
    required this.selectedId,
    required this.conversations,
    required this.isLoading,
    required this.onSelected,
    required this.onSearchChanged,
    required this.onMenuTap,
    required this.onContactsTap,
    this.showBackButton = false,
    this.onBack,
  });

  final String? selectedId;
  final List<Conversation> conversations;
  final bool isLoading;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onMenuTap;
  final VoidCallback onContactsTap;
  final bool showBackButton;
  final VoidCallback? onBack;

  @override
  State<ConversationsPanel> createState() => _ConversationsPanelState();
}

class _ConversationsPanelState extends State<ConversationsPanel> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AlfredColors.panel,
      child: Column(
        children: [
          _Header(
            showBackButton: widget.showBackButton,
            onBack: widget.onBack,
            onMenuTap: widget.onMenuTap,
            onContactsTap: widget.onContactsTap,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _searchController,
              onChanged: widget.onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Cerca conversazione',
                prefixIcon:
                    const Icon(Icons.search, color: AlfredColors.textSecondary),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: widget.isLoading
                ? const Center(child: CircularProgressIndicator())
                : widget.conversations.isEmpty
                    ? const Center(
                        child: Text(
                          'Nessuna conversazione.\nAggiungi un contatto per iniziare.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AlfredColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        itemCount: widget.conversations.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, indent: 76),
                        itemBuilder: (context, index) {
                          final conversation = widget.conversations[index];
                          return ConversationTile(
                            conversation: conversation,
                            selected: conversation.id == widget.selectedId,
                            onTap: () => widget.onSelected(conversation.id),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.showBackButton,
    this.onBack,
    required this.onMenuTap,
    required this.onContactsTap,
  });

  final bool showBackButton;
  final VoidCallback? onBack;
  final VoidCallback onMenuTap;
  final VoidCallback onContactsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AlfredColors.charcoal,
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (showBackButton)
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, color: AlfredColors.textOnDark),
              ),
            const Expanded(
              child: Text(
                'Alfred',
                style: TextStyle(
                  color: AlfredColors.textOnDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            IconButton(
              onPressed: onContactsTap,
              icon: const Icon(Icons.people_outline, color: AlfredColors.textOnDark),
            ),
            IconButton(
              onPressed: onMenuTap,
              icon: const Icon(Icons.more_vert, color: AlfredColors.textOnDark),
            ),
          ],
        ),
      ),
    );
  }
}
