import 'package:flutter/material.dart';

import '../models/chat_peer.dart';
import '../theme/alfred_colors.dart';
import '../utils/avatar_color.dart';

class InboxPeerTile extends StatelessWidget {
  const InboxPeerTile({
    super.key,
    required this.peer,
    required this.selected,
    required this.onTap,
  });

  final ChatPeer peer;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: selected ? AlfredColors.surface : AlfredColors.panel,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _Avatar(peer: peer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            peer.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AlfredColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          peer.timeLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: peer.unreadCount > 0
                                ? AlfredColors.unreadBadge
                                : AlfredColors.textSecondary,
                            fontWeight: peer.unreadCount > 0
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            peer.preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AlfredColors.textSecondary,
                            ),
                          ),
                        ),
                        if (peer.unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          _UnreadBadge(count: peer.unreadCount),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.peer});

  final ChatPeer peer;

  @override
  Widget build(BuildContext context) {
    final initial = avatarInitial(peer.displayName);

    return CircleAvatar(
      radius: 26,
      backgroundColor: peer.resolvedAvatarColor,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AlfredColors.unreadBadge,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
