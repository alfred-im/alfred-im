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
    required this.onContactsTap,
    this.onDrawerTap,
    this.error,
    this.onRetry,
    this.showBackButton = false,
    this.onBack,
    this.showTopBar = true,
  });

  final String? selectedId;
  final List<Conversation> conversations;
  final bool isLoading;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onDrawerTap;
  final VoidCallback onContactsTap;
  final String? error;
  final VoidCallback? onRetry;
  final bool showBackButton;
  final VoidCallback? onBack;
  final bool showTopBar;

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
          if (widget.showTopBar)
            _Header(
              showBackButton: widget.showBackButton,
              onBack: widget.onBack,
              onDrawerTap: widget.onDrawerTap,
              onContactsTap: widget.onContactsTap,
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(12, widget.showTopBar ? 0 : 12, 12, 8),
            child: widget.showTopBar
                ? TextField(
                    controller: _searchController,
                    onChanged: widget.onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Cerca conversazione',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AlfredColors.textSecondary,
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: widget.onSearchChanged,
                          decoration: InputDecoration(
                            hintText: 'Cerca conversazione',
                            prefixIcon: const Icon(
                              Icons.search,
                              color: AlfredColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: widget.onContactsTap,
                        icon: const Icon(Icons.people_outline),
                        tooltip: 'Contatti',
                      ),
                    ],
                  ),
          ),
          const Divider(height: 1),
          Expanded(
            child: widget.isLoading
                ? const Center(child: CircularProgressIndicator())
                : widget.error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AlfredColors.textSecondary,
                                ),
                              ),
                              if (widget.onRetry != null) ...[
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: widget.onRetry,
                                  child: const Text('Riprova'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
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
    this.onDrawerTap,
    required this.onContactsTap,
  });

  final bool showBackButton;
  final VoidCallback? onBack;
  final VoidCallback? onDrawerTap;
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
            if (onDrawerTap != null)
              IconButton(
                onPressed: onDrawerTap,
                icon: const Icon(Icons.menu, color: AlfredColors.textOnDark),
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
          ],
        ),
      ),
    );
  }
}
