import 'package:flutter/material.dart';

import '../models/message.dart';
import '../theme/alfred_colors.dart';
import '../utils/avatar_color.dart';

/// Intestazione compatta autore messaggio (chat di gruppo).
class MessageAuthorHeader extends StatelessWidget {
  const MessageAuthorHeader({
    super.key,
    required this.message,
  });

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final name = message.authorDisplayName;
    if (name == null || name.isEmpty) return const SizedBox.shrink();

    final profileId = message.authorProfileId ?? message.contentAuthorId;
    final avatarUrl = message.authorAvatarUrl;
    final initial = avatarInitial(name);

    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: profileId != null
                ? avatarColorForId(profileId)
                : AlfredColors.border,
            backgroundImage:
                avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AlfredColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
