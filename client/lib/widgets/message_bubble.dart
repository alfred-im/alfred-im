import 'package:flutter/material.dart';

import '../models/message.dart';
import '../theme/alfred_colors.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMine ? AlfredColors.bubbleOutgoing : AlfredColors.panel,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isMine ? 12 : 2),
            bottomRight: Radius.circular(isMine ? 2 : 12),
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
            Text(
              message.body,
              style: const TextStyle(
                color: AlfredColors.textPrimary,
                fontSize: 14.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.timeLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AlfredColors.textSecondary,
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

    if (status == MessageStatus.failed) {
      return Icon(Icons.error_outline, size: 14, color: Colors.red.shade400);
    }

    if (status == MessageStatus.pending) {
      return Icon(Icons.schedule, size: 14, color: color);
    }

    final isDouble = status == MessageStatus.delivered ||
        status == MessageStatus.read;

    return Icon(
      isDouble ? Icons.done_all : Icons.done,
      size: 14,
      color: color,
    );
  }
}
