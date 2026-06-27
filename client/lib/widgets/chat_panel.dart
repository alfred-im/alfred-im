import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_peer.dart';
import '../providers/messages_controller.dart';
import '../theme/alfred_colors.dart';
import '../utils/avatar_color.dart';
import 'anchored_message_list.dart';
import 'chat_input_bar.dart';

class ChatPanel extends StatelessWidget {
  const ChatPanel({
    super.key,
    required this.peer,
    this.showBackButton = false,
    this.onBack,
  });

  final ChatPeer peer;
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
            peer: peer,
            showBackButton: showBackButton,
            onBack: onBack,
          ),
          if (messagesController.isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: AnchoredMessageList(
                messages: messages,
                isLoading: messagesController.isLoading,
                onRetryMessage: messagesController.retryMessage,
              ),
            ),
          ChatInputBar(
            enabled: !messagesController.isSending,
            onSend: messagesController.send,
            onSendGif: messagesController.sendGif,
            onSendVoice: (bytes, durationMs) => messagesController.sendVoice(
              bytes: bytes,
              durationMs: durationMs,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.peer,
    required this.showBackButton,
    this.onBack,
  });

  final ChatPeer peer;
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
                backgroundColor: peer.resolvedAvatarColor,
                child: Text(
                  avatarInitial(peer.displayName),
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
                      peer.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: AlfredColors.textPrimary,
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
