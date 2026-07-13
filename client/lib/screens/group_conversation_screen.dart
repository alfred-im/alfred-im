// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/profile_summary.dart';
import '../providers/group_messages_controller.dart';
import '../theme/alfred_colors.dart';
import '../widgets/anchored_message_list.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/peer_profile_overlay.dart';
import '../widgets/profile_identity.dart';
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
    return ChangeNotifierProvider(
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
            _GroupChatHeader(
              profile: profile,
              showBackButton: showBackButton,
              onBack: onBack,
            ),
            Expanded(
              child: Consumer<GroupMessagesController>(
                builder: (context, controller, _) {
                  if (controller.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (controller.error != null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(controller.error!),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () => unawaited(controller.reload()),
                              child: const Text('Riprova'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return AnchoredMessageList(
                    messages: controller.messages,
                    isLoading: controller.isLoading,
                    showAuthorLabels: true,
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
                onSendImage: (bytes, {required extension, required mime, caption}) =>
                    controller.sendImage(
                  bytes: bytes,
                  extension: extension,
                  mime: mime,
                  caption: caption,
                ),
                onSendVideo: (bytes,
                        {required extension,
                        required mime,
                        required durationSeconds,
                        caption}) =>
                    controller.sendVideo(
                  bytes: bytes,
                  extension: extension,
                  mime: mime,
                  durationSeconds: durationSeconds,
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

class _GroupChatHeader extends StatelessWidget {
  const _GroupChatHeader({
    required this.profile,
    required this.showBackButton,
    this.onBack,
  });

  final ProfileSummary profile;
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
              ProfileAvatar(
                profile: profile,
                radius: 20,
                fontSize: 16,
                onTap: () => showPeerProfileOverlay(context, profile),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ProfileIdentityLines(
                  profile: profile,
                  showUsername: false,
                  nameStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AlfredColors.textPrimary,
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
