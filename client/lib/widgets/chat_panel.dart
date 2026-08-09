// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_peer.dart';
import '../providers/messages_controller.dart';
import '../providers/reception_allowlist_controller.dart';
import '../utils/auth_controller_scope.dart';
import '../utils/mention_navigation.dart';
import '../theme/alfred_colors.dart';
import 'anchored_message_list.dart';
import 'chat_ingress_panel.dart';
import 'chat_input_bar.dart';
import 'inline_error_retry.dart';
import 'message_action_menu.dart';

export 'chat_ingress_panel.dart' show ChatIngressPanel, ChatPanelHeader;

class ChatPanel extends StatefulWidget {
  const ChatPanel({
    super.key,
    required this.peer,
    this.showBackButton = false,
    this.onBack,
    this.showAuthorLabels = false,
  });

  final ChatPeer peer;
  final bool showBackButton;
  final VoidCallback? onBack;
  final bool showAuthorLabels;

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ReceptionAllowlistController?>()?.ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final messagesController = context.watch<MessagesController>();
    final auth = watchAuthControllerOrNull(context);
    final allowlist = context.watch<ReceptionAllowlistController?>();
    final messages = messagesController.messages;
    final canCompose = allowlist != null &&
        !allowlist.isLoading &&
        allowlist.isProfileAllowed(widget.peer.profileId);

    return ColoredBox(
      color: AlfredColors.surface,
      child: Column(
        children: [
          ChatPanelHeader(
            peer: widget.peer,
            showBackButton: widget.showBackButton,
            onBack: widget.onBack,
          ),
          if (messagesController.isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (messagesController.error != null)
            Expanded(
              child: InlineErrorRetry(
                message: messagesController.error!,
                onRetry: () => unawaited(messagesController.reload()),
                icon: Icons.chat_bubble_outline,
                retryWithIcon: true,
              ),
            )
          else
            Expanded(
              child: AnchoredMessageList(
                messages: messages,
                isLoading: messagesController.isLoading,
                showAuthorLabels: widget.showAuthorLabels,
                viewerUsername: auth?.username,
                onMentionTap: auth != null
                    ? (username) =>
                        openChatFromMentionUsername(context, username)
                    : null,
                hasMoreOlder: messagesController.hasMoreOlder,
                isLoadingOlder: messagesController.isLoadingOlder,
                onLoadOlder: messagesController.hasMoreOlder
                    ? () => unawaited(messagesController.loadOlderMessages())
                    : null,
                onRetryMessage: messagesController.retryMessage,
                onMessageTap: (message) => unawaited(
                  showMessageActionMenu(
                    context: context,
                    message: message,
                    controller: messagesController,
                  ),
                ),
                onReactionSummaryTap: (message, emoji) => unawaited(
                  messagesController.applyReaction(
                    message: message,
                    emoji: emoji,
                  ),
                ),
              ),
            ),
          ChatInputBar(
            enabled: !messagesController.isSending && canCompose,
            onSend: messagesController.send,
            onSendGif: messagesController.sendGif,
            onSendImage: (bytes, {caption}) => messagesController.sendImage(
              bytes: bytes,
              caption: caption,
            ),
            onSendVideo: (file, {caption}) =>
                messagesController.sendVideoFromPicker(
              file: file,
              caption: caption,
            ),
            onSendVoice: (bytes, durationMs) => messagesController.sendVoice(
              bytes: bytes,
              durationMs: durationMs,
            ),
            onSendLocation: (latitude, longitude) => messagesController.sendLocation(
              latitude: latitude,
              longitude: longitude,
            ),
          ),
        ],
      ),
    );
  }
}
