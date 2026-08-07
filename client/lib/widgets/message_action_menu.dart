// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

import '../data/emoji_catalog.dart';
import '../models/message.dart';
import '../providers/messages_controller.dart';
import '../theme/alfred_colors.dart';

Future<void> showMessageActionMenu({
  required BuildContext context,
  required ChatMessage message,
  required MessagesController controller,
}) async {
  if (!message.canReact) return;
  controller.openMessageActions(message);
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AlfredColors.panel,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _MessageActionMenuSheet(
      message: message,
      controller: controller,
    ),
  );
  controller.closeMessageActions();
}

class _MessageActionMenuSheet extends StatefulWidget {
  const _MessageActionMenuSheet({
    required this.message,
    required this.controller,
  });

  final ChatMessage message;
  final MessagesController controller;

  @override
  State<_MessageActionMenuSheet> createState() => _MessageActionMenuSheetState();
}

class _MessageActionMenuSheetState extends State<_MessageActionMenuSheet> {
  final _scrollController = ScrollController();
  int _loadedCount = EmojiCatalog.pageSize;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 120) return;
    if (_loadedCount >= EmojiCatalog.totalCount) return;
    setState(() {
      _loadedCount = (_loadedCount + EmojiCatalog.pageSize)
          .clamp(0, EmojiCatalog.totalCount);
    });
  }

  Future<void> _onEmojiTap(String emoji) async {
    if (_applying) return;
    setState(() => _applying = true);
    try {
      await widget.controller.applyReaction(
        message: widget.message,
        emoji: emoji,
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final glyphs = EmojiCatalog.page(offset: 0, limit: _loadedCount);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Reaction',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AlfredColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.45,
              child: GridView.builder(
                controller: _scrollController,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: glyphs.length,
                itemBuilder: (context, index) {
                  final emoji = glyphs[index];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _applying ? null : () => _onEmojiTap(emoji),
                      borderRadius: BorderRadius.circular(8),
                      child: Center(
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
