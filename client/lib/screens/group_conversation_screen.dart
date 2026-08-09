// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/profile_summary.dart';
import '../providers/group_messages_controller.dart';
import '../utils/auth_controller_scope.dart';
import '../utils/mention_navigation.dart';
import '../theme/alfred_colors.dart';
import '../utils/session_scope_keys.dart';
import '../widgets/anchored_message_list.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/chat_ingress_panel.dart';
import '../widgets/inline_error_retry.dart';
import '../services/account_session.dart';

/// Conversazione account gruppo — header allineato a [ChatPanel].
class GroupConversationScreen extends StatelessWidget {
  const GroupConversationScreen({
    super.key,
    required this.session,
    required this.profile,
    this.showBackButton = false,
    this.onBack,
    this.onMessagesChanged,
  });

  final AccountSession session;
  final ProfileSummary profile;
  final bool showBackButton;
  final VoidCallback? onBack;
  final Future<void> Function()? onMessagesChanged;

  @override
  Widget build(BuildContext context) {
    final auth = watchAuthControllerOrNull(context);
    return ChangeNotifierProvider(
      key: groupSessionKey(session, 'group-messages'),
      create: (_) => GroupMessagesController(
        userId: session.userId,
        messageService: session.messageService,
        messageMediaService: session.messageMediaService,
        profileService: session.profileService,
        onMessagesChanged: onMessagesChanged,
      ),
      child: ColoredBox(
        color: AlfredColors.surface,
        child: Column(
          children: [
            ChatPanelHeader(
              profile: profile,
              showBackButton: showBackButton,
              onBack: onBack,
              showCallActions: false,
            ),
            Expanded(
              child: Consumer<GroupMessagesController>(
                builder: (context, controller, _) {
                  if (controller.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (controller.error != null) {
                    return InlineErrorRetry(
                      message: controller.error!,
                      onRetry: () => unawaited(controller.reload()),
                      gapBeforeRetry: 12,
                      messageStyle: Theme.of(context).textTheme.bodyMedium,
                    );
                  }
                  return AnchoredMessageList(
                    messages: controller.messages,
                    isLoading: controller.isLoading,
                    showAuthorLabels: true,
                    viewerUsername: auth?.username,
                    onMentionTap: auth != null
                        ? (username) =>
                            openChatFromMentionUsername(context, username)
                        : null,
                  );
                },
              ),
            ),
            Consumer<GroupMessagesController>(
              builder: (context, controller, _) => ChatInputBar(
                enabled: !controller.isSending,
                hintText: 'Messaggio al gruppo (allow list)…',
                onSend: controller.send,
                onSendGif: controller.sendGif,
                onSendImage: (bytes, {caption}) => controller.sendImage(
                  bytes: bytes,
                  caption: caption,
                ),
                onSendVideo: (file, {caption}) =>
                    controller.sendVideoFromPicker(
                  file: file,
                  caption: caption,
                ),
                onSendVoice: (bytes, durationMs) => controller.sendVoice(
                  bytes: bytes,
                  durationMs: durationMs,
                ),
                onSendLocation: (latitude, longitude) => controller.sendLocation(
                  latitude: latitude,
                  longitude: longitude,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
