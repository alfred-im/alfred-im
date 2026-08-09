// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

import '../models/chat_peer.dart';
import '../models/profile_summary.dart';
import '../theme/alfred_colors.dart';
import 'peer_profile_overlay.dart';
import 'profile_identity.dart';

/// Ingresso chat: header peer + spinner, senza [MessagesController].
///
/// File leggero — importabile senza trascinare il bundle media di [ChatPanel].
class ChatIngressPanel extends StatelessWidget {
  const ChatIngressPanel({
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
    return ColoredBox(
      color: AlfredColors.surface,
      child: Column(
        children: [
          ChatPanelHeader(
            peer: peer,
            showBackButton: showBackButton,
            onBack: onBack,
          ),
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}

/// Header condiviso tra ingresso, [ChatPanel] e [GroupConversationScreen].
class ChatPanelHeader extends StatelessWidget {
  const ChatPanelHeader({
    super.key,
    this.peer,
    this.profile,
    required this.showBackButton,
    this.onBack,
    this.showCallActions = true,
  }) : assert(peer != null || profile != null);

  final ChatPeer? peer;
  final ProfileSummary? profile;
  final bool showBackButton;
  final VoidCallback? onBack;
  final bool showCallActions;

  ProfileSummary get _profile => peer?.profile ?? profile!;

  @override
  Widget build(BuildContext context) {
    final resolvedProfile = _profile;

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
                profile: resolvedProfile,
                radius: 20,
                fontSize: 16,
                onTap: () => showPeerProfileOverlay(context, resolvedProfile),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ProfileIdentityLines(
                  profile: resolvedProfile,
                  showUsername: false,
                  nameStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AlfredColors.textPrimary,
                  ),
                ),
              ),
              if (showCallActions) ...[
                IconButton(
                  onPressed: null,
                  icon: const Icon(Icons.videocam_outlined),
                ),
                IconButton(
                  onPressed: null,
                  icon: const Icon(Icons.call_outlined),
                ),
                IconButton(
                  onPressed: null,
                  icon: const Icon(Icons.more_vert),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
