import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/profile_summary.dart';
import '../providers/group_messages_controller.dart';
import '../services/account_session.dart';
import '../theme/alfred_colors.dart';
import '../widgets/anchored_message_list.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/profile_identity.dart';

/// Shell account gruppo: allow list + profilo in alto, conversazione unica sotto.
class GroupConversationScreen extends StatelessWidget {
  const GroupConversationScreen({
    super.key,
    required this.session,
    required this.profile,
    required this.onAllowedPeopleTap,
    required this.onProfileTap,
    this.onMessagesChanged,
  });

  final AccountSession session;
  final ProfileSummary profile;
  final VoidCallback onAllowedPeopleTap;
  final VoidCallback onProfileTap;
  final Future<void> Function()? onMessagesChanged;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GroupMessagesController(
        userId: session.userId,
        messageService: session.messageService,
        profileService: session.profileService,
        onMessagesChanged: onMessagesChanged,
      ),
      child: ColoredBox(
        color: AlfredColors.surface,
        child: Column(
          children: [
            _GroupTopBar(
              profile: profile,
              onProfileTap: onProfileTap,
              onAllowedPeopleTap: onAllowedPeopleTap,
            ),
            const Divider(height: 1),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupTopBar extends StatelessWidget {
  const _GroupTopBar({
    required this.profile,
    required this.onProfileTap,
    required this.onAllowedPeopleTap,
  });

  final ProfileSummary profile;
  final VoidCallback onProfileTap;
  final VoidCallback onAllowedPeopleTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AlfredColors.panel,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ProfileAvatar(profile: profile, radius: 22),
                      title: ProfileIdentityLines(
                        profile: profile,
                        nameStyle: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: const Text('Account gruppo'),
                      onTap: onProfileTap,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Persone consentite',
                    onPressed: onAllowedPeopleTap,
                    icon: const Icon(Icons.verified_user_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: onAllowedPeopleTap,
                icon: const Icon(Icons.verified_user_outlined, size: 18),
                label: const Text('Persone consentite'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
