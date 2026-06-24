import 'package:flutter/material.dart';

import '../models/message.dart';
import '../theme/alfred_colors.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMine = message.isMine;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.65,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          decoration: BoxDecoration(
            color: isMine ? AlfredColors.bubbleOutgoing : AlfredColors.bubbleIncoming,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(8),
              topRight: const Radius.circular(8),
              bottomLeft: Radius.circular(isMine ? 8 : 2),
              bottomRight: Radius.circular(isMine ? 2 : 8),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  message.body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AlfredColors.textPrimary,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.timeLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AlfredColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 4),
                    _Checkmarks(status: message.status),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Checkmarks extends StatelessWidget {
  const _Checkmarks({required this.status});

  final MessageStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status == MessageStatus.read
        ? AlfredColors.accentBlue
        : AlfredColors.textSecondary;

    return Icon(
      status == MessageStatus.sent ? Icons.check : Icons.done_all,
      size: 14,
      color: color,
    );
  }
}
