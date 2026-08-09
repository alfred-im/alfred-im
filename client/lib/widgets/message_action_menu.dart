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
  final rootMessenger = ScaffoldMessenger.maybeOf(context);
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AlfredColors.panel,
    isScrollControlled: true,
    enableDrag: false,
    showDragHandle: false,
    builder: (sheetContext) => _MessageActionMenuSheet(
      message: message,
      controller: controller,
      rootMessenger: rootMessenger,
    ),
  );
}

class _MessageActionMenuSheet extends StatefulWidget {
  const _MessageActionMenuSheet({
    required this.message,
    required this.controller,
    required this.rootMessenger,
  });

  final ChatMessage message;
  final MessagesController controller;
  final ScaffoldMessengerState? rootMessenger;

  @override
  State<_MessageActionMenuSheet> createState() => _MessageActionMenuSheetState();
}

class _MessageActionMenuSheetState extends State<_MessageActionMenuSheet> {
  final _scrollController = ScrollController();
  bool _applying = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showError(String text) {
    final messenger = widget.rootMessenger ?? ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _onEmojiTap(String emoji) async {
    if (_applying) return;
    setState(() => _applying = true);
    try {
      await widget.controller.applyReaction(
        message: widget.message,
        emoji: emoji,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      _showError('Reaction non inviata. Riprova.');
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.55;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottomInset),
        child: SizedBox(
          height: sheetHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Reaction',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AlfredColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Chiudi',
                    onPressed:
                        _applying ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: GridView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                    ),
                    itemCount: EmojiCatalog.totalCount,
                    itemBuilder: (context, index) {
                      final emoji = EmojiCatalog.all[index];
                      return Semantics(
                        button: true,
                        label: 'Reaction $emoji',
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _applying ? null : () => _onEmojiTap(emoji),
                          child: Center(
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 26),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (_applying)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
