import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../theme/alfred_colors.dart';
import 'conversation_tile.dart';

class ConversationsPanel extends StatelessWidget {
  const ConversationsPanel({
    super.key,
    required this.selectedId,
    required this.onSelected,
    this.showBackButton = false,
    this.onBack,
  });

  final String? selectedId;
  final ValueChanged<String> onSelected;
  final bool showBackButton;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AlfredColors.panel,
      child: Column(
        children: [
          _Header(showBackButton: showBackButton, onBack: onBack),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cerca conversazione',
                prefixIcon: const Icon(Icons.search, color: AlfredColors.textSecondary),
                suffixIcon: IconButton(
                  onPressed: null,
                  icon: const Icon(Icons.filter_list, color: AlfredColors.textSecondary),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: MockData.conversations.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
              itemBuilder: (context, index) {
                final conversation = MockData.conversations[index];
                return ConversationTile(
                  conversation: conversation,
                  selected: conversation.id == selectedId,
                  onTap: () => onSelected(conversation.id),
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
  const _Header({required this.showBackButton, this.onBack});

  final bool showBackButton;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AlfredColors.charcoal,
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
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
              onPressed: null,
              icon: const Icon(Icons.more_vert, color: AlfredColors.textOnDark),
            ),
          ],
        ),
      ),
    );
  }
}
