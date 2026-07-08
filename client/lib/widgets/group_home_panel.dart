import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/profile_summary.dart';
import '../models/group_active_author.dart';
import '../providers/group_home_controller.dart';
import '../theme/alfred_colors.dart';
import '../widgets/inbox_peer_tile.dart';
import '../widgets/profile_identity.dart';

/// Home account gruppo — guscio uniforme a [InboxPanel], senza ricerca né FAB.
class GroupHomePanel extends StatelessWidget {
  const GroupHomePanel({
    super.key,
    required this.profile,
    required this.conversationSelected,
    required this.onConversationTap,
    required this.onProfileTap,
    required this.onAllowedPeopleTap,
    this.onDrawerTap,
  });

  final ProfileSummary profile;
  final bool conversationSelected;
  final VoidCallback onConversationTap;
  final VoidCallback onProfileTap;
  final VoidCallback onAllowedPeopleTap;
  final VoidCallback? onDrawerTap;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GroupHomeController>();

    return ColoredBox(
      color: AlfredColors.panel,
      child: Column(
        children: [
          _Header(
            title: profile.displayName,
            onDrawerTap: onDrawerTap,
            onProfileTap: onProfileTap,
            onAllowedPeopleTap: onAllowedPeopleTap,
          ),
          const Divider(height: 1),
          Expanded(
            child: controller.isLoading
                ? const Center(child: CircularProgressIndicator())
                : controller.error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                controller.error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AlfredColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: () =>
                                    context.read<GroupHomeController>().reload(),
                                child: const Text('Riprova'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 12),
                        children: [
                          _SummarySection(controller: controller),
                          const Divider(height: 1, indent: 12, endIndent: 12),
                          _ActiveAuthorsSection(
                            authors: controller.activeAuthors,
                          ),
                          const Divider(height: 1),
                          if (controller.conversationTile != null)
                            InboxPeerTile(
                              peer: controller.conversationTile!,
                              selected: conversationSelected,
                              onTap: onConversationTap,
                            ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    this.onDrawerTap,
    required this.onProfileTap,
    required this.onAllowedPeopleTap,
  });

  final String title;
  final VoidCallback? onDrawerTap;
  final VoidCallback onProfileTap;
  final VoidCallback onAllowedPeopleTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 0),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (onDrawerTap != null)
              IconButton(
                onPressed: onDrawerTap,
                icon: const Icon(Icons.menu),
                tooltip: 'Account',
              ),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AlfredColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              onPressed: onProfileTap,
              icon: const Icon(Icons.person_outline),
              tooltip: 'Profilo',
            ),
            IconButton(
              onPressed: onAllowedPeopleTap,
              icon: const Icon(Icons.verified_user_outlined),
              tooltip: 'Persone consentite',
            ),
          ],
        ),
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.controller});

  final GroupHomeController controller;

  @override
  Widget build(BuildContext context) {
    final createdAt = controller.createdAt;
    final birthLabel = createdAt != null
        ? 'Nato il ${GroupHomeController.formatBirthDate(createdAt)}'
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${controller.totalMessageCount} messaggi',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AlfredColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
          ),
          if (birthLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              birthLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AlfredColors.textSecondary,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActiveAuthorsSection extends StatelessWidget {
  const _ActiveAuthorsSection({required this.authors});

  final List<GroupActiveAuthor> authors;

  @override
  Widget build(BuildContext context) {
    if (authors.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          'Persone più attive',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AlfredColors.textPrimary,
              ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Persone più attive',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AlfredColors.textPrimary,
                ),
          ),
        ),
        ...authors.map((author) => _ActiveAuthorRow(author: author)),
      ],
    );
  }
}

class _ActiveAuthorRow extends StatelessWidget {
  const _ActiveAuthorRow({required this.author});

  final GroupActiveAuthor author;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          ProfileAvatar(profile: author.profile, radius: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              author.profile.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AlfredColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          Text(
            '${author.messageCount}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AlfredColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
