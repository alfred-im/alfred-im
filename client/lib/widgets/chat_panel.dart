import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/conversation.dart';
import '../providers/messages_controller.dart';
import '../theme/alfred_colors.dart';
import 'chat_input_bar.dart';
import 'message_bubble.dart';

class ChatPanel extends StatelessWidget {
  const ChatPanel({
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
    final messagesController = context.watch<MessagesController>();
    final messages = messagesController.messages;

    return ColoredBox(
      color: AlfredColors.surface,
      child: Column(
        children: [
          _ChatHeader(
            conversation: conversation,
            showBackButton: showBackButton,
            onBack: onBack,
          ),
          if (messagesController.isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: messages.length,
                itemBuilder: (context, index) =>
                    MessageBubble(message: messages[index]),
              ),
            ),
          ChatInputBar(
            enabled: !messagesController.isSending,
            onSend: messagesController.send,
          ),
        ],
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.conversation,
    required this.showBackButton,
    this.onBack,
  });

  final Conversation conversation;
  final bool showBackButton;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AlfredColors.panel,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AlfredColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              if (showBackButton)
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                ),
              CircleAvatar(
                backgroundColor: conversation.avatarColor,
                child: Text(
                  conversation.name[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: AlfredColors.textPrimary,
                      ),
                    ),
                    Text(
                      conversation.protocol == 'internal'
                          ? 'Alfred'
                          : 'In attesa bridge',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AlfredColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: null,
                icon: const Icon(Icons.videocam_outlined),
              ),
              IconButton(onPressed: null, icon: const Icon(Icons.call_outlined)),
              IconButton(onPressed: null, icon: const Icon(Icons.more_vert)),
            ],
          ),
        ),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 72,
              color: AlfredColors.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Alfred',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AlfredColors.textSecondary,
                    fontWeight: FontWeight.w300,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Seleziona una conversazione per iniziare',
              style: TextStyle(color: AlfredColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
