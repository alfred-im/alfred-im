import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models/conversation.dart';
import '../theme/alfred_colors.dart';
import '../widgets/chat_panel.dart';
import '../widgets/conversations_panel.dart';

/// Layout principale stile WhatsApp Web: lista + chat.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedId = MockData.conversations.first.id;
  bool _showListOnMobile = false;

  static const _breakpoint = 720.0;

  Conversation? get _selected {
    final id = _selectedId;
    if (id == null) return null;
    for (final c in MockData.conversations) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= _breakpoint;
    final selected = _selected;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: width >= 1100 ? 380 : 320,
              child: ConversationsPanel(
                selectedId: _selectedId,
                onSelected: (id) => setState(() => _selectedId = id),
              ),
            ),
            const VerticalDivider(width: 1, color: AlfredColors.border),
            Expanded(
              child: selected == null
                  ? const EmptyChatPlaceholder()
                  : ChatPanel(conversation: selected),
            ),
          ],
        ),
      );
    }

    if (selected == null || _showListOnMobile) {
      return Scaffold(
        body: ConversationsPanel(
          selectedId: _selectedId,
          onSelected: (id) => setState(() {
            _selectedId = id;
            _showListOnMobile = false;
          }),
        ),
      );
    }

    return Scaffold(
      body: ChatPanel(
        conversation: selected,
        showBackButton: true,
        onBack: () => setState(() => _showListOnMobile = true),
      ),
    );
  }
}
